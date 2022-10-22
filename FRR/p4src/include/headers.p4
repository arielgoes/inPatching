/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define N_PREFS 1024
#define PORT_WIDTH 32
#define N_PORTS 128
#define N_PATHS 128
#define N_SW_ID 8
#define N_HOPS 128

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
typedef bit<20> label_t;

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_PATH_HOPS = 0x45;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}
header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<2>    ecn;
    bit<6>    dscp;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header pathHops_t{
    bit<64> pkt_id;
    bit<32> numHop; //counts the current hop position (switch by switch)
    bit<48> pkt_timestamp; //the instant of time the packet ingressed the depot switch
    bit<32> path_id; //same as "meta.indexPath"
    bit<32> which_alt_switch; //tells at which switch ID the depot will try to deviate from the primary path at a single hop. NOTE: value zero is reserved for primary path - i.e., no deviation at any hop.
    bit<8> has_visited_depot; //whether it is the first time visiting the depot switch: (0 = NO; 1 = YES)
    bit<64> num_times_curr_switch; // 63 switches + 1 filler (ease indexation). last switch ID is the leftmost bit (the most significant one).
    bit<8> is_alt; //force the probe to stay in the alternative path
    bit<8> is_tracker; //special probe to force a packet at every X time interval into the primary path
}

struct metadata {
    bit<32> indexPath; //used for both "primaryNH" and "alternativeNH" registers
    bit<32> depotPort; //universal (for now)
    bit<32> nextHop; //next hop of the current path
    bit<32> lenPrimaryPathSize; //length of the provided primary path (by the control plane)
    bit<32> lenAlternativePathSize; //length of the provided alternative path (by the control plane)
    bit<32> lenHashPrimaryPathSize; //force packet to go by the alternative path
}
struct headers {
    ethernet_t                      ethernet;
    ipv4_t                          ipv4;
    pathHops_t                      pathHops;
}