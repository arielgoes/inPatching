#!/usr/bin/env python3
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, get_if_list, get_if_hwaddr
from scapy.all import Ether, IP, UDP, TCP
from time import sleep


def main():
    #addr = "10.1.1.2" # l3 - 1 host
    #addr = "10.1.2.2" # l3 - 2 hosts
    addr = "10.0.1.2" # mixed - 2 hosts
    iface = "h1-eth1" 

    print("sending on interface %s to %s" % (iface, str(addr)))

    #for _ in range(1): #number of random packets
    while True:
        pkt = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
        pkt = pkt /IP(dst=addr) / TCP(dport=random.randint(5000,60000), sport=random.randint(49152,65535))
        sendp(pkt, iface=iface, verbose=False)
        sleep(0.5)

if __name__ == '__main__':
    main()
