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
    //Nomenclature: primary/alternativeNH_<first/second time visiting the hop>_<link failure - e.g., s1-s2>
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_2;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_2;

    //The flow logic to access/update alternative paths: path_id_X_pointer_reg -> whichAltSwitchReg -> path_id_X_path_reg

    //Path 0
    register<bit<32>>(128) path_id_0_path_reg; // flow (path) 0: ['s1', 's2', 's3', 's4', 's5', 's1']. //NOTE: First position must NOT be used. Start by index 1, because whichAltSwitchReg reserves the first position for the primary path hops
    register<bit<32>>(1) path_id_0_pointer_reg; //points to the next swId where the depot must try to reroute
    //e.g., path:['s1', 's2', 's3', 's4', 's5', 's1'], path_id_0_path_pointer: 1,  return: 's2'.

    //Path 1
    //register<bit<32>>(128) path_id_1_path_reg;
    //register<bit<32>>(1) path_id_1_pointer_reg;

    //Path N...
    //...
    //...


    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPrimaryPathSize;
    register<bit<32>>(N_PATHS) lenAlternativePathSize;

    //Stores the depot port to host (special case - last hop no failures - i.e., max timestamp not exceeded)
    register<bit<32>>(1) depotPortReg;

    //Contains the switch id (populated by the control plane)
    register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7

    //Contains the depot id (populated by the control plane)
    register<bit<N_SW_ID>>(1) depotIdReg; //depot switch id (universal)


    action drop() {
        mark_to_drop(standard_metadata);
    }

    /*action read_primary_port_1(bit<32> indexPath){ //Read primary next hop and write result into meta.nextHop.
        meta.indexPath = indexPath;
        primaryNH_1.read(meta.nextHop,  meta.indexPath);
    }*/

    action read_primary_port_1(){ //Read primary next hop and write result into meta.nextHop.
        primaryNH_1.read(meta.nextHop, hdr.pathHops.path_id);
    }

    action read_alternative_port_1(){ //Read alternative next hop and write result into meta.nextHop.
        alternativeNH_1.read(meta.nextHop, hdr.pathHops.path_id);
    }

    action read_primary_port_2(){ //Read primary next hop and write result into meta.nextHop.
        primaryNH_2.read(meta.nextHop,  hdr.pathHops.path_id);
    }

    action read_alternative_port_2(){ //Read alternative next hop and write result into meta.nextHop.
        alternativeNH_2.read(meta.nextHop, hdr.pathHops.path_id);
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
        depotPortReg.read(meta.depotPort, 0);
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

    table primary_path_exact_2 {
        key = {
            hdr.pathHops.which_alt_switch: exact;
        }
        actions = {
            read_primary_port_2;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table alternative_path_exact_1 {
        key = {
            hdr.pathHops.which_alt_switch: exact;
        }
        actions = {
            read_alternative_port_1;
            drop;
        }
        size = 512;
        default_action = drop;
    }

    table alternative_path_exact_2 {
        key = {
            hdr.pathHops.which_alt_switch: exact;
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

    register<bit<32>>(1) debugReg; //(debug)
    register<bit<32>>(1) debugReg2; //(debug)
    

    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();

            //get switch id
            bit<8> swId;
            swIdReg.read(swId, 0);

            //shift-left idea... (testing)
            bit<64> mask = 1; //00000000000000000000000000000001 (first position is just a filler) - IT IS ACTUALLY INDEXING "N_SW_ID - 1"
            mask = mask << swId; //shift operations are limited to variables of size up to 8 bits (bit<8>)
            //debugReg.write(0, mask); //(debugging)

            //get current timestamp
            bit<48> curr_time;
            curr_time = standard_metadata.ingress_global_timestamp;

            //get depot id
            bit<N_SW_ID> depotId;
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

            //get length of the primary and alternative paths
            len_primary_path.apply(); //sets the "meta.lenPrimaryPath"
            len_alternative_path.apply(); //sets the "meta.lenAlternativePath"

            //FRR control
            if(swId == depotId && hdr.pathHops.which_alt_switch == 0 && hdr.pathHops.pkt_timestamp - last_seen < threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 0;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.which_alt_switch == 0 && hdr.pathHops.pkt_timestamp - last_seen >= threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 1;
                if(hdr.pathHops.path_id == 0){
                    //gets the index into a variable
                    bit<32> path_id_0_pointer_var;
                    path_id_0_pointer_reg.read(path_id_0_pointer_var, 0);

                    //rotate index of the next switch attemptive (swIdTry)
                    if(path_id_0_pointer_var == 0){ //if the pointer is at the first position (index 0), ...
                        path_id_0_pointer_reg.write(0, 1); //...increment it to 1, because it is reserved for the primary path...
                        path_id_0_pointer_reg.read(path_id_0_pointer_var, 0); //...and read again for the updated pointer value
                    }else if(path_id_0_pointer_var > 0 && path_id_0_pointer_var < meta.lenPrimaryPathSize){ 
                        path_id_0_pointer_reg.write(0, path_id_0_pointer_var + 1); //...update it normally...
                        path_id_0_pointer_reg.read(path_id_0_pointer_var, 0); //... and read again for the updated pointer value
                    }else{ //path_id_0_pointer_var == meta.lenPrimaryPath
                        path_id_0_pointer_reg.write(0, 1); //...reset it to 1
                        path_id_0_pointer_reg.read(path_id_0_pointer_var, 0); //... and read again for the updated pointer value
                    }

                    bit<32> swIdTry;
                    path_id_0_path_reg.read(swIdTry, path_id_0_pointer_var);
                    hdr.pathHops.which_alt_switch = swIdTry;
                    debugReg2.write(0, swIdTry); //(debug)
                }/*else if(hdr.pathHops.path_id == 1){
                    bit<32> path_id_1_pointer_var;
                    path_id_1_pointer_reg.read(path_id_1_pointer_var);
                    ...
                }*/
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.which_alt_switch > 0 && hdr.pathHops.pkt_timestamp - last_seen < threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 0;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }else if(swId == depotId && hdr.pathHops.which_alt_switch > 0 && hdr.pathHops.pkt_timestamp - last_seen >= threshold && hdr.pathHops.has_visited_depot > 0){
                //hdr.pathHops.is_alt = 1;
                last_seen_pkt_timestamp.write(0, curr_time);
                last_seen_pkt_timestamp.read(last_seen, 0);
            }

            //primary path cases
            if(hdr.pathHops.which_alt_switch == 0){
                
                //update hop counter
                //update_curr_path_size();

                primaryNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                if((hdr.pathHops.num_times_curr_switch_primary & mask == 0) && (meta.nextHop != 9999)){ //bit is zero, so this is the first time we are visiting this hop in the current path
                    primary_path_exact_1.apply(); //try to find the next hop by applying the first primary hop
                    hdr.pathHops.num_times_curr_switch_primary = (hdr.pathHops.num_times_curr_switch_primary & ~mask) | ((bit<64>)1 << swId); 
                }else{ //if the next hop is not valid (i.e., nextHop == 9999), apply the second primary table.
                    primary_path_exact_2.apply(); //try the second position - i.e., the second primary table which encompasses the second primary register
                }
            }
            //alternative path cases
            else if(hdr.pathHops.which_alt_switch > 0 && swId == (bit<8>)hdr.pathHops.which_alt_switch){ //this line may overflow
                //alternativeNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                if((hdr.pathHops.num_times_curr_switch_alternative & mask == 0) && (meta.nextHop != 9999)){
                    alternative_path_exact_1.apply();
                    hdr.pathHops.num_times_curr_switch_alternative = (hdr.pathHops.num_times_curr_switch_alternative & ~mask) | ((bit<64>)1 << swId); //change the bit representing the switch ID from 0 to 1, as it was visited once now. 
                }else{
                    alternative_path_exact_2.apply();
                }

                /*bit<32> back_to_trails;
                path_id_0_path_reg.read(back_to_trails, hdr.pathHops.numHop+1); //if the current switch id is the following in line in the primary path, reset the flag to primary path again
                if(hdr.pathHops.numHop == back_to_trails){
                    hdr.pathHops.which_alt_switch = 0; //after performing a deviation, return to the original path hops.    
                }*/
            }

            // Do not change the following lines: They set the egress port
            standard_metadata.egress_spec = (bit<9>) meta.nextHop;


            //Now, we check if this is a special case: the last cycle hop and force to send the package to the host insted of "next switch" (either primary or alternative port)
            if(hdr.pathHops.which_alt_switch == 0 && hdr.pathHops.numHop == meta.lenPrimaryPathSize && hdr.pathHops.has_visited_depot > 0){
                read_depot_port();
                standard_metadata.egress_spec = (bit<9>) meta.depotPort;
                //Reset curr path size
                reset_curr_path_size();
            }else if(hdr.pathHops.which_alt_switch > 0 && hdr.pathHops.numHop == meta.lenAlternativePathSize && hdr.pathHops.has_visited_depot > 0){
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
