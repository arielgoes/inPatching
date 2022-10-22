#!/usr/bin/env python3
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP
from scapy.fields import *
from time import sleep

class PathHops(Packet):
    fields_desc = [BitField("pkt_id", 0, 64),
                   IntField("numHop", 0),
                   BitField("num_pkts", 0, 64),
                   BitField("pkt_timestamp", 0, 48),
                   IntField("path_id", 0),
                   ByteField("has_visited_depot", 0)] #00000000 (0) OR 11111111 (1). I'm using 8 bits because P4 does not accept headers which are not multiple of 8
bind_layers(IP, PathHops, proto=0x45)


def main():
    #addr = "10.1.1.2" # l3 - 1 host
    #addr = "10.1.2.2" # l3 - 2 hosts
    addr = "10.0.1.2" # mixed - 2 hosts
    #addr = "10.0.1.1" # mixed - 1 host
    iface = "h1-eth1"

    print("sending on interface %s to %s" % (iface, str(addr)))

    #for _ in range(1): #number of random packets
    pkt_id = 0
    while True: 
        pkt = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff') / IP(dst=addr, proto=0x45) / PathHops(path_id=0, pkt_id=pkt_id)
        sendp(pkt, iface=iface, verbose=False)
        pkt_id += 1
if __name__ == '__main__':
    main()
