#!/usr/bin/env python3
import sys
import struct

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, IPOption
from scapy.all import IP, UDP, Raw, Ether
from scapy.layers.inet import _IPOption_HDR
from scapy.fields import *

class PathHops(Packet):
    fields_desc = [BitField("pkt_id", 0, 64),
                   IntField("numHop", 0),
                   BitField("num_pkts", 0, 64),
                   BitField("pkt_timestamp", 0, 48),
                   IntField("path_id", 0),
                   ByteField("has_visited_depot", 0)] #00000000 (0) OR 11111111 (1). I'm using 8 bits because P4 does not accept headers which are not multiple of 8
bind_layers(IP, PathHops, proto=0x45)

def handle_pkt(pkt):
    print("got a packet")
    pkt.show2()
#    hexdump(pkt)
    sys.stdout.flush()


def main():
    #iface = 'h1-eth1'
    #iface = 'h2-eth5'
    iface = 'h2-eth1'
    print("sniffing on %s" % iface)
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))


if __name__ == '__main__':
    main()

