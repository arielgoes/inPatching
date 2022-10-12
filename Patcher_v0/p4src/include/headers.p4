/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define N_PREFS 1024
#define PORT_WIDTH 32
#define N_PORTS 512
#define N_SW_ID 8

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
typedef bit<20> label_t;

const bit<16> TYPE_PATH_HOPS = 0x45;
const bit<16> TYPE_IPV4 = 0x0800;

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
    bit<32> numHop;
    bit<48> pkt_timestamp; //the instant of time the packet ingressed the depot switch
    bit<32> path_id; //same as "meta.indexPath"
    bit<8> has_visited_depot; //whether it is the first time visiting the depot switch: (0 = NO; 1 = YES)
}

struct metadata {
    bit<32> indexPath; //used for both "primaryNH" and "alternativeNH" registers
    bit<1> linkState;
    bit<32> depotPort; //universal (for now)
    bit<32> nextHop; //next hop of the current path
    bit<32> lenPrimaryPathSize; //length of the provided primary path (by the control plane)
    bit<32> lenAlternativePathSize; //length of the provided alternative path (by the control plane)
}

struct headers {
    ethernet_t                      ethernet;
    ipv4_t                          ipv4;
    pathHops_t                      pathHops;
}
