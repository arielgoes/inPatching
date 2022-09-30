/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"




/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    //time management
    register<bit<48>>(1) maxTimeOutDepotReg; //e.g., max amount of time until the depot consider the packet dropped
    register<bit<48>>(1) last_seen_pkt_timestamp;

    // Registers to look up the port of the default next hop.
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_2;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_2;

    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPrimaryPathSize;
    register<bit<32>>(N_PATHS) lenAlternativePathSize;

    //Stores the depot port to host (special case - last hop no failures - i.e., max timestamp not exceeded)
    register<bit<32>>(1) depotPort;

    //Contains the switch id (populated by the control plane)
    register<bit<16>>(1) swIdReg;

    //register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7
    register<bit<N_SW_ID>>(1) depotIdReg; //depot switch id (universal)


    //temporario (debugging)
    register<bit<8>>(1) isAltReg;
    register<bit<32>>(1) numHopReg;

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action read_primary_port_1(bit<32> indexPath){ //Read primary next hop and write result into meta.nextHop.
        meta.indexPath = indexPath;
        primaryNH_1.read(meta.nextHop,  meta.indexPath);
    }

    action read_alternative_port_1(bit<32> indexPath){ //Read alternative next hop and write result into meta.nextHop.
        meta.indexPath = indexPath;
        alternativeNH_1.read(meta.nextHop, meta.indexPath);
    }

    action read_primary_port_2(bit<32> indexPath){ //Read primary next hop and write result into meta.nextHop.
        meta.indexPath = indexPath;
        primaryNH_2.read(meta.nextHop,  meta.indexPath);
    }

    action read_alternative_port_2(bit<32> indexPath){ //Read alternative next hop and write result into meta.nextHop.
        meta.indexPath = indexPath;
        alternativeNH_2.read(meta.nextHop, meta.indexPath);
    }    

    action read_len_primary_path(bit<32> indexPath){
        meta.indexPath = indexPath;
        lenPrimaryPathSize.read(meta.lenPrimaryPathSize, meta.indexPath);
    }

    action read_len_alternative_path(bit<32> indexPath){
        meta.indexPath = indexPath;
        lenAlternativePathSize.read(meta.lenAlternativePathSize, meta.indexPath);
    }

    action update_curr_path_size(){
        hdr.pathHops.numHop = hdr.pathHops.numHop + 1;
    }

    action reset_curr_path_size(){
        hdr.pathHops.numHop = 0;
    }

    action read_depot_port(){
        //Stores the depot port to host (global, for now)
        depotPort.read(meta.depotPort, 0);
    }


    table primary_path_exact_1 {
        key = {
            hdr.pathHops.numHop: exact;
        }
        actions = {
            read_primary_port_1;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table alternative_path_exact_1 {
        key = {
            hdr.pathHops.numHop: exact;
        }
        actions = {
            read_alternative_port_1;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table primary_path_exact_2 {
        key = {
            hdr.pathHops.numHop: exact;
        }
        actions = {
            read_primary_port_2;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table alternative_path_exact_2 {
        key = {
            hdr.pathHops.numHop: exact;
        }
        actions = {
            read_alternative_port_2;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table len_primary_path {
        key = {
            hdr.pathHops.path_id: exact;
        }
        actions = {
            read_len_primary_path;
            NoAction();
        }
        size = 512;
        default_action = NoAction();
    }

    table len_alternative_path {
        key = {
            hdr.pathHops.path_id: exact;
        }
        actions = {
            read_len_alternative_path;
            NoAction();
        }
        size = 512;
        default_action = NoAction();
    }
    

    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();
            //debug into a register

            primary_path_exact_1.apply();
            if(meta.nextHop == 9999){
                primary_path_exact_2.apply();
            }

            //get current timestamp
            bit<48> curr_time;
            curr_time = standard_metadata.ingress_global_timestamp;

            //get switch id
            bit<16> swId;
            swIdReg.read(swId, 0);

            //get depot id
            bit<16> depotId;
            depotIdReg.read(depotId, 0);

            //last seen timestamp
            bit<48> last_seen;
            last_seen_pkt_timestamp.read(last_seen, 0);

            //read max time out (e.g., 300ms) into a variable before 
            bit<48> threshold;
            maxTimeOutDepotReg.read(threshold, 0);

            //The packet enters the depot switch for the first time (beggining of the cycle)
            if(swId == depotId && hdr.pathHops.has_visited_depot == 0){
                hdr.pathHops.pkt_timestamp = curr_time;
                if(last_seen == 0){
                    last_seen_pkt_timestamp.write(0, curr_time);
                    last_seen_pkt_timestamp.read(last_seen, 0);
                }
                hdr.pathHops.has_visited_depot = 1;
            }else{ //at other hops, insert timestamp anyways
                hdr.pathHops.pkt_timestamp = curr_time;
            }

            //FRR control
            if(swId == depotId && hdr.pathHops.is_alt == 0 && hdr.pathHops.pkt_timestamp - last_seen < threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 0;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.is_alt == 0 && hdr.pathHops.pkt_timestamp - last_seen >= threshold && hdr.pathHops.has_visited_depot > 0){
                hdr.pathHops.is_alt = 1;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.is_alt == 1 && hdr.pathHops.pkt_timestamp - last_seen < threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 0;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.is_alt == 1 && hdr.pathHops.pkt_timestamp - last_seen >= threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 1;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }

            if(hdr.pathHops.is_alt > 0){
                alternative_path_exact_1.apply();
                if(meta.nextHop == 9999){
                    alternative_path_exact_2.apply();
                }
            }

            // Do not change the following lines: They set the egress port
            standard_metadata.egress_spec = (bit<9>) meta.nextHop;

            //temporario (debugging)
            isAltReg.write(0, hdr.pathHops.is_alt);
            numHopReg.write(0, hdr.pathHops.numHop);


            //Now, we check if this is a special case: the last cycle hop and force to send the package to the host insted of "next switch" (either primary or alternative port)
            len_primary_path.apply();
            len_alternative_path.apply();
            if(hdr.pathHops.is_alt == 0 && hdr.pathHops.numHop == meta.lenPrimaryPathSize && hdr.pathHops.has_visited_depot > 0){
                read_depot_port();
                standard_metadata.egress_spec = (bit<9>) meta.depotPort;
                //Reset curr path size
                reset_curr_path_size();
            }else if(hdr.pathHops.is_alt == 1 && hdr.pathHops.numHop == meta.lenAlternativePathSize && hdr.pathHops.has_visited_depot > 0){
                read_depot_port();
                standard_metadata.egress_spec = (bit<9>) meta.depotPort;
                //Reset curr path size
                reset_curr_path_size();
            }
        }
    }
}
/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    apply {

    }

}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
  update_checksum(
      hdr.ipv4.isValid(),
            { hdr.ipv4.version,
        hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}




/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
