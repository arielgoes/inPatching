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

#threads
from concurrent.futures import process
from multiprocessing import Pool
from threading import Thread
import time
import argparse
import sys
import socket
import random
import struct
import numpy as np

class PathHops(Packet):
    fields_desc = [BitField("pkt_id", 0, 64),
                   BitField("numHop", 0, 8),
                   IntField("path_id", 0),
                   BitField("which_alt_switch", 0, 32), #tells at which hop the depot will try to deviate from the primary path at a single hop. NOTE: value zero is reserved for primary path - i.e., no deviation at any hop.
                   ByteField("has_visited_depot", 0), #00000000 (0) OR 11111111 (1). I'm using 8 bits because P4 does not accept headers which are not multiple of 8
                   BitField("num_times_curr_switch", 0, 64), # 31 switches + 1 filler (ease indexation). last switch ID is the leftmost bit (the most significant one)
                   BitField("is_alt", 0, 8), #force packet to go by the alternative paths
                   BitField("is_tracker", 0, 8), #every 'X' time interval, we send a probe tracker at the primary path to see if is alive again. If so, force other incoming packets in the given flow to use its primary path. 
                   BitField("sw_overlap", 0, 32)] 
bind_layers(IP, PathHops, proto=0x45)

temporario2
#enviar vários pacotes diferentes de maneira simultanea
def send_packets_parallel(addr, iface, num_thread, qtd_packets):
    for i in range(num_thread*qtd_packets,(((num_thread+1)*qtd_packets)-1),2):
        pkt1 = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff') / IP(dst=addr, proto=0x45) / PathHops(path_id=0, pkt_id=i+1)
        pkt2 = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff') / IP(dst=addr, proto=0x45) / PathHops(path_id=0, pkt_id=i+2)
        sendp(pkt1, iface=iface, verbose=False) #envia pacotes de maneira sequencial
        sendp(pkt2, iface=iface, verbose=False) #envia pacotes de maneira sequencial


def main():
    #addr = "10.1.1.2" # l3 - 1 host
    #addr = "10.1.2.2" # l3 - 2 hosts
    addr = "10.0.1.2" # mixed - 2 hosts
    #addr = "10.0.1.1" # mixed - 1 host
    iface = "h1-eth1"

    num_threads= 2
    qtd_packets_thread= 1000
    qtd_packets_total= num_threads*4*qtd_packets_thread

    threads = []
    for thread in range(num_threads):
        t = Thread(target=send_packets_parallel, args=(addr, iface, thread, qtd_packets_thread))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()



    print("sending on interface %s to %s" % (iface, str(addr)))

if __name__ == '__main__':
    main()