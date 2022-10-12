/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"

#define PORT_WIDTH 32
#define N_PORTS 512
#define N_PATHS 512



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

    // Register containing link states. 0: No Problems. 1: Link failure.
    // This register is updated by CLI.py, you only need to read from it.
    register<bit<1>>(N_PORTS) linkState;

    //This register is used to mantain the size of each path - used to compare whether the current size is equal to the max size
    register<bit<32>>(N_PATHS) lenPrimaryPathSize;
    register<bit<32>>(N_PATHS) lenAlternativePathSize;

    //Stores the depot port to host
    register<bit<32>>(1) depotPort;

    //Contains the depot id (populated by the control plane)
    register<bit<N_SW_ID>>(1) depotIdReg; //depot switch id (universal)

    //Contains the switch id (populated by the control plane)
    register<bit<N_SW_ID>>(1) swIdReg; //switch id [1, topology size] - e.g., s1,s2,s3,s4,s5,s6,s7. # of switches = 7


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
        depotPort.read(meta.depotPort, 0);
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
    

    apply {
        if (hdr.ipv4.isValid()){

            //update hop counter
            update_curr_path_size();

            //read path size
            len_primary_path.apply();
            len_alternative_path.apply();

            //get switch id
            bit<8> swId;
            swIdReg.read(swId, 0);

            //get current timestamp
            bit<48> curr_time;
            curr_time = standard_metadata.ingress_global_timestamp; //for more flows, this should be an array (register)

            //get depot id
            bit<N_SW_ID> depotId;
            depotIdReg.read(depotId, 0);

            //last seen timestamp
            bit<48> last_seen;
            last_seen_pkt_timestamp.read(last_seen, hdr.pathHops.path_id);


            /*if(swId == depotId && hdr.pathHops.pkt_timestamp - last_seen >= threshold){

            }*/

            //Set egress port
            standard_metadata.egress_spec = (bit<9>) meta.nextHop;

            

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
