/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"


register<bit<64>>(1) global_pkt_counter;

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
    register<bit<48>>(1) temporario1_experimento_Reg;
    register<bit<48>>(1) temporario2_experimento_Reg;

    // Registers to look up the port of the default next hop.
    //Nomenclature: primary/alternativeNH_<first/second time visiting the hop>_<link failure - e.g., s1-s2>
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_2;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_2;

    //The flow logic to access/update alternative paths: path_id_X_pointer_reg -> whichAltSwitchReg -> path_id_X_path_reg

    register<bit<1>>(1) flagFirstAltReg; //used for experiments

    //Ensures the next packets keep using the alternative path
    register<bit<32>>(N_PATHS) whichSwitchAltReg;

    register<bit<32>>(N_PATHS) path_id_pointer_reg; //points to the next swId where the depot must try to reroute

    //Path 0
    register<bit<32>>(N_HOPS) path_id_0_path_reg; // flow (path) 0: ['s1', 's2', 's3', 's4', 's5', 's1']. //NOTE: First position must NOT be used. Start by index 1, because whichAltSwitchReg reserves the first position for the primary path hops
    //e.g., path:['s1', 's2', 's3', 's4', 's5', 's1'], path_id_path_pointer: 1,  return: 's2'.

    //Path 1
    register<bit<32>>(N_HOPS) path_id_1_path_reg;

    //Path N...
    //...


    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPrimaryPathSize;
    register<bit<32>>(N_PATHS) lenAlternativePathSize;

    //Special len primary switch: stores unique switch ids
    register<bit<32>>(N_PATHS) lenHashPrimaryPathSize;

    //Stores the depot port to host (special case - last hop no failures - i.e., max timestamp not exceeded)
    register<bit<32>>(1) depotPortReg;

    //Contains the switch id (populated by the control plane)
    register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7

    //Contains the depot id (populated by the control plane)
    register<bit<N_SW_ID>>(1) depotIdReg; //depot switch id (universal)

    register<bit<8>>(N_PATHS) isAltReg; //register that forces the use of alternative paths for subsequent packets,
    //until a timeout occurs or a tracker packet (is_track == 1) is sent through the primary path and prooves it is working again

    register<bit<8>>(N_PATHS) forcePrimaryPathReg; //if a tracker packet prooved the primary path is working, force all packets in a given flow to use the primary path until a new timeout occurs
    //0: Don't force packets, 1: force packets to use the primary path

    action drop() {
        mark_to_drop(standard_metadata);
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


    table len_primary_path {
        key = {
            hdr.pathHops.path_id: exact;
        }
        actions = {
            read_len_primary_path;
            NoAction();
        }
        size = N_PATHS;
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
        size = N_PATHS;
        default_action = NoAction();
    }

    register<bit<48>>(1) temp; //(debug)
    register<bit<48>>(1) temp2; //(debug)
    register<bit<48>>(1) curr_time_Reg; //(debug)



    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();
            //numHopDebugReg.write(0, hdr.pathHops.numHop);

            //To get timestamp for experiments, I need to count the packets to get correct start and end timestamps
            bit<64> num_pkts;
            global_pkt_counter.read(num_pkts, 0);
            global_pkt_counter.write(0, num_pkts + 1);

            //get switch id
            bit<8> swId;
            swIdReg.read(swId, 0);

            bit<32> swIdTry = 0;

            //shift-left idea... (testing)
            bit<64> mask = 1; //00000000000000000000000000000001 (first position is just a filler) - IT IS ACTUALLY INDEXING "N_SW_ID - 1"
            mask = mask << swId; //shift operations are limited to variables of size up to 8 bits (bit<8>)
            //debugReg.write(0, mask); //(debugging)

            //get current timestamp
            bit<48> curr_time;
            curr_time = standard_metadata.ingress_global_timestamp; //for more flows, this should be an array (register)
            curr_time_Reg.write(0, curr_time);

            //get depot id
            bit<N_SW_ID> depotId;
            depotIdReg.read(depotId, 0);

            //last seen timestamp
            bit<48> last_seen;
            last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);


            //read max time out (e.g., 300ms) into a variable before 
            bit<48> threshold;
            maxTimeOutDepotReg.read(threshold, 0);

            bit<32> path_id_pointer_var = 0;
            bit<8> forcePrimaryPathVar = 0;
            forcePrimaryPathReg.read(forcePrimaryPathVar, hdr.pathHops.path_id);

            //once a alternative path is take, maintain it until a tracker packet or a "new" timeout occurs
            bit<8> isAltVar;
            isAltReg.read(isAltVar, hdr.pathHops.path_id);

            //The packet enters the depot switch for the first time (beggining of the cycle)
            if(swId == depotId && hdr.pathHops.has_visited_depot == 0){
                if(last_seen == 0 && num_pkts == (bit<64>)0){
                    temporario1_experimento_Reg.write(0, curr_time); //(utilizado para experimentos)
                    //last_seen_pkt_timestamp.write(0, curr_time);
                    //last_seen_pkt_timestamp.read(last_seen, 0);
                }
            }

            //update packet timestamp
            hdr.pathHops.pkt_timestamp = curr_time;

            temp.write(0, standard_metadata.ingress_global_timestamp - last_seen);

            //get length of the primary and alternative paths
            len_primary_path.apply(); //sets the "meta.lenPrimaryPath"
            len_alternative_path.apply(); //sets the "meta.lenAlternativePath"
            lenHashPrimaryPathSize.read(meta.lenHashPrimaryPathSize, 0);


            //FRR control (all the decisions are made at the depot/starting node)
            if(swId == depotId && (bit<48>)hdr.pathHops.pkt_timestamp - (bit<48>)last_seen >= threshold && hdr.pathHops.has_visited_depot == 0 && num_pkts > 0){
                if(hdr.pathHops.path_id == 0){ //first flow...
                    //gets the index into a variable
                    path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id);

                    //rotate index of the next switch attemptive (swIdTry)
                    if(path_id_pointer_var == 0){ //if the pointer is at the first position (index 0), ...
                        path_id_pointer_reg.write(hdr.pathHops.path_id, 1); //...increment it to 1, because it is reserved for the primary path...
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //...and read again for the updated pointer value
                    }else if(path_id_pointer_var > 0 && path_id_pointer_var < meta.lenHashPrimaryPathSize){ 
                        path_id_pointer_reg.write(hdr.pathHops.path_id, path_id_pointer_var + 1); //...update it normally...
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //... and read again for the updated pointer value
                    }else{ //path_id_pointer_var == meta.lenPrimaryPath
                        //path_id_pointer_reg.write(hdr.pathHops.path_id, 0);
                        path_id_pointer_reg.write(hdr.pathHops.path_id, 1); //...reset it to 1
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //... and read again for the updated pointer value
                    }

                    path_id_0_path_reg.read(swIdTry, path_id_pointer_var);
                    hdr.pathHops.which_alt_switch = swIdTry;
                    whichSwitchAltReg.write(hdr.pathHops.path_id, swIdTry);
                    hdr.pathHops.is_alt = 1;
                    isAltReg.write(hdr.pathHops.path_id, 1);
                    isAltReg.read(isAltVar, hdr.pathHops.path_id);
                    forcePrimaryPathReg.write(hdr.pathHops.path_id, 0); //stop forcing packets using primary path in a given flow
                }else if(hdr.pathHops.path_id == 1){ //second flow
                    //gets the index into a variable
                    path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id);

                    //rotate index of the next switch attemptive (swIdTry)
                    if(path_id_pointer_var == 0){ //if the pointer is at the first position (index 0), ...
                        path_id_pointer_reg.write(hdr.pathHops.path_id, 1); //...increment it to 1, because it is reserved for the primary path...
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //...and read again for the updated pointer value
                    }else if(path_id_pointer_var > 0 && path_id_pointer_var < meta.lenHashPrimaryPathSize){ 
                        path_id_pointer_reg.write(hdr.pathHops.path_id, path_id_pointer_var + 1); //...update it normally...
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //... and read again for the updated pointer value
                    }else{ //path_id_pointer_var == meta.lenPrimaryPath
                        path_id_pointer_reg.write(hdr.pathHops.path_id, 1); //...reset it to 1
                        path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id); //... and read again for the updated pointer value
                    }

                    path_id_1_path_reg.read(swIdTry, path_id_pointer_var);
                    hdr.pathHops.which_alt_switch = swIdTry;
                    whichSwitchAltReg.write(hdr.pathHops.path_id, swIdTry);
                    hdr.pathHops.is_alt = 1;
                    isAltReg.write(hdr.pathHops.path_id, 1);
                    isAltReg.read(isAltVar, hdr.pathHops.path_id);
                    forcePrimaryPathReg.write(hdr.pathHops.path_id, 0); //stop forcing packets using primary path in a given flow
                }
            }else if(swId == depotId && hdr.pathHops.is_tracker > 0 && hdr.pathHops.has_visited_depot > 0){ //special case (is_tracker) probe
                isAltReg.write(hdr.pathHops.path_id, 0); //reset isAltReg
                isAltReg.read(isAltVar, hdr.pathHops.path_id);
                hdr.pathHops.is_alt = 0;
                path_id_pointer_reg.write(hdr.pathHops.path_id, 0);
                whichSwitchAltReg.write(hdr.pathHops.path_id, 0);
                hdr.pathHops.which_alt_switch = 0;

                //force packets to use the primary path
                forcePrimaryPathReg.write(hdr.pathHops.path_id, 1);                
            }

            //force the packet to keep using the alternative path as long as a "new" timeout do not occurs, then it selects the next candidate switch in round-robin fashion
            if(isAltVar > 0 && hdr.pathHops.pkt_timestamp - last_seen < threshold){
                hdr.pathHops.is_alt = 1;
                forcePrimaryPathReg.write(hdr.pathHops.path_id, 0); //stop forcing primary path (if it is somehow)
                path_id_pointer_reg.read(path_id_pointer_var, hdr.pathHops.path_id);
                hdr.pathHops.which_alt_switch = swIdTry;
                whichSwitchAltReg.read(swIdTry, hdr.pathHops.path_id);
                hdr.pathHops.which_alt_switch = swIdTry;

                //used for experiments only 
                bit<1> x;
                flagFirstAltReg.read(x, 0);
                if(x == (bit<1>) 0){
                    temporario2_experimento_Reg.write(0, curr_time); //(end timestamp)
                    flagFirstAltReg.write(0, 1);
                }
            }


            //primary path cases
            if(hdr.pathHops.which_alt_switch == 0){
                primaryNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                if((hdr.pathHops.num_times_curr_switch & mask == 0) && (meta.nextHop != 9999)){ //bit is zero, so this is the first time we are visiting this hop in the current path
                    hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId); 
                }else{ //if the next hop is not valid (i.e., nextHop == 9999), apply the second primary table.
                    primaryNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId);
                }
                hdr.pathHops.which_alt_switch = 0;
                hdr.pathHops.is_alt = 0;
            }
            //alternative path cases
            else if(hdr.pathHops.which_alt_switch > 0 && swId == (bit<8>)hdr.pathHops.which_alt_switch){ //this line may overflow
                alternativeNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                if((hdr.pathHops.num_times_curr_switch & mask == 0) && (meta.nextHop != 9999)){
                    hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId); //change the bit representing the switch ID from 0 to 1, as it was visited once now. 
                }else{
                    alternativeNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId);
                }
                hdr.pathHops.which_alt_switch = 0; //after performing a deviation, return to the original path hops.
                hdr.pathHops.is_alt = 1; //is using alternative hop    
            }
            //default
            else{
                hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId);
                primaryNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                hdr.pathHops.is_alt = 0;
                if((meta.nextHop == 9999)){
                    primaryNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 0;
                }/*if(meta.nextHop == 9999){ //if I let this commented, it will timeout until it finds "that" next hop working again.
                    alternativeNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 1;
                }else{
                    alternativeNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 1;
                }*/
            }

            //place holder...


            forcePrimaryPathReg.read(forcePrimaryPathVar, hdr.pathHops.path_id);
            if(hdr.pathHops.is_tracker > 0 || forcePrimaryPathVar > 0){ //if is_tracker: it is a special probe (is_tracker), force it into the primary path
                hdr.pathHops.num_times_curr_switch = (hdr.pathHops.num_times_curr_switch & ~mask) | ((bit<64>)1 << swId);
                primaryNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                hdr.pathHops.is_alt = 0;
                if((meta.nextHop == 9999)){
                    primaryNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 0;
                }
            }

            
            // Do not change the following lines: They set the egress port
            standard_metadata.egress_spec = (bit<9>) meta.nextHop;

            //update last seen packet
            if(swId == depotId && hdr.pathHops.has_visited_depot > 0){
                last_seen_pkt_timestamp.write(hdr.pathHops.path_id, standard_metadata.ingress_global_timestamp);
                last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);    
            }

            temp2.write(0, hdr.pathHops.pkt_timestamp - last_seen);

            //mark as visited (at the depot)
            if(swId == depotId && hdr.pathHops.has_visited_depot == 0){
                hdr.pathHops.has_visited_depot = 1;
            }

            //Now, we check if this is a special case: the last cycle hop and force to send the package to the host insted of "next switch" (either primary or alternative port)
            if(swId == depotId && hdr.pathHops.numHop >= meta.lenPrimaryPathSize && hdr.pathHops.has_visited_depot > 0){
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
