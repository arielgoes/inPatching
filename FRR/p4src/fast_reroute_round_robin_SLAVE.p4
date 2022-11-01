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
    register<bit<48>>(N_PATHS) last_seen_pkt_timestamp;

    // Registers to look up the port of the default next hop.
    //Nomenclature: primary/alternativeNH_<first/second time visiting the hop>_<link failure - e.g., s1-s2>
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) primaryNH_2;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_1;
    register<bit<PORT_WIDTH>>(N_PATHS) alternativeNH_2;

    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPrimaryPathSize;
    register<bit<32>>(N_PATHS) lenAlternativePathSize;

    //Special len primary switch: stores unique switch ids
    register<bit<32>>(N_PATHS) lenHashPrimaryPathSize;

    //Stores the depot port to host (special case - last hop no failures - i.e., max timestamp not exceeded)
    register<bit<32>>(1) depotPortReg;

    //Contains the switch id (populated by the control plane)
    register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7

    register<bit<8>>(N_PATHS) forcePrimaryPathReg; //if a tracker packet prooved the primary path is working, force all packets in a given flow to use the primary path until a new timeout occurs
    //0: Don't force packets, 1: force packets to use the primary path

    action drop() {
        mark_to_drop(standard_metadata);
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

    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();

            //get switch id
            bit<8> swId;
            swIdReg.read(swId, 0);

            //used to get/set hop/switch overlap - if any
            bit<32> sw_overlap_var;

            //shift-left idea... (testing)
            bit<64> mask = 1; //00000000000000000000000000000001 (first position is just a filler) - IT IS ACTUALLY INDEXING "N_SW_ID - 1"
            mask = mask << swId; //shift operations are limited to variables of size up to 8 bits (bit<8>)

            bit<8> forcePrimaryPathVar = 0;
            forcePrimaryPathReg.read(forcePrimaryPathVar, hdr.pathHops.path_id);

            //get length of the primary and alternative paths
            lenPrimaryPathSize.read(meta.lenPrimaryPathSize, hdr.pathHops.path_id);
            lenAlternativePathSize.read(meta.lenAlternativePathSize, meta.indexPath);
            lenHashPrimaryPathSize.read(meta.lenHashPrimaryPathSize, hdr.pathHops.path_id);

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
                }

                //if I let this commented, it will always work, but it is unrealistic. (Used for debugging)
                /*if(meta.nextHop == 9999){
                    alternativeNH_1.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 1;
                }else{
                    alternativeNH_2.read(meta.nextHop, hdr.pathHops.path_id);
                    hdr.pathHops.is_alt = 1;
                }*/
            }

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
