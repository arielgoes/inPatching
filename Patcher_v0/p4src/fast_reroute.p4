/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"

#define PORT_WIDTH 32
#define N_PORTS 512
#define N_PATHS 512


//Contains the switch id (populated by the control plane)
register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7


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
    register<bit<48>>(N_PATHS) last_seen_pkt_timestamp;

    // Register to look up the port of the default next hop.
    register<bit<PORT_WIDTH>>(N_PATHS) NH; //When a failure occurs, rewrite the next hop positions in this register

    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPathSize;

    //Stores the depot port to host (special case - last hop no failures - i.e., max timestamp not exceeded)
    register<bit<32>>(1) depotPortReg;

    //Contains the depot id (populated by the control plane)
    register<bit<N_SW_ID>>(1) depotIdReg; //depot switch id (universal)


    action drop() {
        mark_to_drop(standard_metadata);
    }

    action read_len_path(bit<32> indexPath){
        meta.indexPath = indexPath;
        lenPathSize.read(meta.lenPathSize, meta.indexPath);
    }

    action update_curr_path_size(){
        hdr.pathHops.numHop = hdr.pathHops.numHop + 1;
    }

    action reset_curr_path_size(){
        hdr.pathHops.numHop = 0;
    }

    action read_depot_port(){
        //Stores the depot port to host (global, for now)
        depotPortReg.read(meta.depotPort, 0);
    }

    action clone_packet_i2e(){
        // Clone from ingress to egress pipeline
        clone(CloneType.I2E, REPORT_MIRROR_SESSION_ID);
    }


    table len_path_size {
        key = {
            hdr.pathHops.path_id: exact;
        }
        actions = {
            read_len_path;
            NoAction();
        }
        size = N_PATHS;
        default_action = NoAction();
    }
    
    register<bit<32>>(1) numHopDebugReg; //(debug) 

    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();

            numHopDebugReg.write(0, hdr.pathHops.numHop);


            //get switch id
            bit<8> swId;
            swIdReg.read(swId, 0);

            //get current timestamp
            bit<48> curr_time;
            curr_time = standard_metadata.ingress_global_timestamp; //for more flows, this should be an array (register)
            time_control_plane.write(0, curr_time);

            //get depot id
            bit<N_SW_ID> depotId;
            depotIdReg.read(depotId, 0);

            //last seen timestamp
            bit<48> last_seen;
            last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);

            //read max time out (e.g., 300ms) into a variable before 
            bit<48> threshold;
            maxTimeOutDepotReg.read(threshold, 0);


            //The packet enters the depot switch for the first time (beggining of the cycle)
            if(swId == depotId && hdr.pathHops.has_visited_depot == 0){
                hdr.pathHops.pkt_timestamp = curr_time;
                if(last_seen == 0){
                    last_seen_pkt_timestamp.write(hdr.pathHops.path_id, curr_time);
                    last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);
                }
                hdr.pathHops.has_visited_depot = 1;
            }else{ //at other hops, insert timestamp anyways
                hdr.pathHops.pkt_timestamp = curr_time;
            }

            //get length of the primary and alternative paths
            len_path_size.apply(); //sets the "meta.lenPath"

            //If the packet timed out, send it to the control plane
            if(swId == depotId && hdr.pathHops.pkt_timestamp - last_seen >= threshold && hdr.pathHops.has_visited_depot > 0){
                clone_packet_i2e();
            }

            //update last seen packet
            last_seen_pkt_timestamp.write(hdr.pathHops.path_id, curr_time);
            last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);


            //read the next hop
            NH.read(meta.nextHop, hdr.pathHops.path_id);

            //Set egress port, based on the next hop
            standard_metadata.egress_spec = (bit<9>) meta.nextHop;


            //Now, we check if this is a special case: the last cycle hop and force to send the package to the host insted of "next switch" (either primary or alternative port)
            if(swId == depotId && hdr.pathHops.numHop >= meta.lenPathSize && hdr.pathHops.has_visited_depot > 0){
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

    register<bit<64>>(1) cpu_counter;

    action change_egress_port() {
        standard_metadata.egress_spec = (bit<9>) 7; //set last port as the controller port
        hdr.ipv4.tos = PKT_INSTANCE_TYPE_INGRESS_CLONE; //set type of service
    }

    action increment_counter(){
        bit<64> counter_var;
        cpu_counter.read(counter_var, 0);
        cpu_counter.write(0, counter_var + 1);
        cpu_counter.read(counter_var, 0);
        hdr.pathHops.num_pkts = counter_var;
    }


    apply {
        // In case the "instance type" is a cloned packet, modify its headers
        // Otherwise, do not further process
        if(standard_metadata.instance_type == PKT_INSTANCE_TYPE_INGRESS_CLONE){
            change_egress_port();
            increment_counter();
            //hdr.pathHops.setInvalid(); //don't need to use pathHops header
        }
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
              hdr.ipv4.tos,
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
