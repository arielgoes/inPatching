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


# path_id == 0 <-> path 0 (first path). Each path has a primary NH and alternative NH
#BitField("name", default_value, size)
class PathHops(Packet):
    fields_desc = [IntField("numHop", 0),
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
    #while True:
    pkt = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff') / IP(dst=addr, proto=0x45) / PathHops(path_id=0)
    sendp(pkt, iface=iface, verbose=False)
    #sleep(0.5)

if __name__ == '__main__':
    main()
