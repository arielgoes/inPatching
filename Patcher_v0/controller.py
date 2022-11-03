import os
import sys
#from cli import CLI
from re import search
from random import random
from networkx.algorithms import all_pairs_dijkstra
from networkx import shortest_simple_paths

from p4utils.utils.helper import load_topo
from p4utils.utils.topology import *
from p4utils.utils.sswitch_thrift_API import SimpleSwitchThriftAPI
from collections import defaultdict
from scapy.all import Packet
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, IPOption
from scapy.all import IP, UDP, Raw, Ether
from scapy.layers.inet import _IPOption_HDR
from scapy.fields import *
from time import sleep

#time elapse
from datetime import datetime
from datetime import timedelta 

# this function will be held by the CLI later...
import subprocess

class PathHops(Packet):
    fields_desc = [BitField("pkt_id", 0, 64),
                   IntField("numHop", 0),
                   BitField("num_pkts", 0, 64),
                   BitField("pkt_timestamp", 0, 48),
                   IntField("path_id", 0),
                   ByteField("has_visited_depot", 0), #00000000 (0) OR 11111111 (1). I'm using 8 bits because P4 does not accept headers which are not multiple of 8
                   BitField("last_seen_temp", 0, 48)]
bind_layers(IP, PathHops, proto=0x45)

class RerouteController(object):
    """Controller for the fast rerouting exercise."""

    def __init__(self):
        """Initializes the topology and data structures."""

        if not os.path.exists('topology.json'):
            print("Could not find topology object!\n")
            raise Exception

        self.primary_paths = [['s1', 's2', 's3', 's4', 's5', 's1']]
        self.alternative_paths = [[]]
        self.depot = self.primary_paths[0][0]
        print("depot ==>", self.depot)


        self.topo = load_topo('topology.json')
        self.controllers = {}
        self.connect_to_switches()
        self.reset_states()
        self.maxTimeOut = 10000 #300000us = 300ms = 0.3sec
        self.max_num_repeated_switch_hops = 2
        print("=======================> PRIMARY ENTRIES <=======================")
        self.install_primary_entries()

        #reseting every link state (e.g., link states that are currently 'down' become 'up' once again.)
        self.do_reset(line="s1 s2")
        self.do_reset(line="s2 s3")
        self.do_reset(line="s3 s4")
        self.do_reset(line="s4 s5")
        self.do_reset(line="s5 s1")

        #Fail link
        #self.do_fail(line="s1 s2")
        #self.do_fail(line="s2 s3")
        #self.do_fail(line="s3 s4")
        #self.do_fail(line="s4 s5")
        self.do_fail(line="s5 s1")

        print("=======================> CONTROL PLANE REROUTE ENTRIES <=======================")
        #self.install_rerouting_rules(failures=self.failed_links) #calculate new routes on the control plane
        self.install_rerouting_rules() #calculate new routes on the control plane



    #def do_reset(self, line=""):  # pylint: disable=unused-argument
    def do_reset(self, line):
        """Set all interfaces back up."""
        failed_links = self.check_all_links()
        for link in failed_links:
            print("Resetting failure for link %s-%s." % link)
            self.update_interfaces(link, "up")
            #self.update_linkstate(link, "up")


    def connect_to_switches(self):
        """Connects to all the switches in the topology."""
        for p4switch in self.topo.get_p4switches():
            thrift_port = self.topo.get_thrift_port(p4switch)
            self.controllers[p4switch] = SimpleSwitchThriftAPI(thrift_port)


    def reset_states(self):
        """Resets registers, tables, etc."""
        for control in self.controllers.values():
            control.reset_state()


    def install_primary_entries(self):

        #reset states (registers, tables, etc.)
        self.reset_states()
        
        #save the depot switch id into a register for further operations
        control = self.controllers[self.depot]
        control.register_write('depotIdReg', 0, self.depot[1:])

        #set the max time out for further operations
        control.register_write('maxTimeOutDepotReg', 0, self.maxTimeOut)

        #set depot (only one port for all the probe paths - for now)
        neighbors_intfs = self.topo.get_interfaces_to_node(self.depot)
        #print("neighbors_intfs (host) ==> ", neighbors_intfs)
        if 'h2' in neighbors_intfs.values(): #if the switch is connect to the host, the switch is the depot
            depot_port = self.topo.node_to_node_port_num(self.depot, 'h2')
            #print("depot_port ==> " + str(depot_port))
            control = self.controllers[self.depot]
            control.register_write('depotPortReg', 0, depot_port) #register_write(register_name, index, value)
            #sys.exit() # force exit (debugging)


        curr_path_index = 0
        for lst in self.primary_paths:
            print("-------------------- Path " + str(curr_path_index) + " --------------------")

            #store the length of the current path in a register for logic operations (in the P4 code)
            print("..... primary path length:")
            visited = []
            for dummy, switch in enumerate(lst): #dummy is a filler variable - not used
                control = self.controllers[switch]
                control.register_write('lenPathSize', curr_path_index, len(lst))
                subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)
                if switch not in visited:
                    print('--' + str(switch) + '--')
                    control.table_add('len_path_size', 'read_len_path', match_keys=[str(curr_path_index)], action_params=[str(curr_path_index)]) #match_keys=[str(0)] -> is.alt == 0, i.e., PRIMARY PATH
                visited.append(switch)

            print()

            print("..... route rules")
            switch_dict = defaultdict()
            curr_hop = 1
            for index, switch in enumerate(lst):
                #print("curr_path_index ==> " + str(curr_path_index))

                # install route rules at the registers            
                if index + 1 < len(lst):
                    curr_switch = lst[index]
                    next_switch = lst[index+1]
                    print("(",curr_switch, "Next ->", next_switch, ")")
                    #print("index ==> ", index)

                    # get neighbors
                    neighbors_intfs = self.topo.get_interfaces_to_node(curr_switch)
                    #print("neighbors_intfs =>", neighbors_intfs) # print output: intf => {'s1-eth1': 'h1', 's1-eth2': 's2', 's1-eth3': 's6', 's1-eth4': 's7'}

                    #hash the switch ids and see its frequency along the path: e.g., {'s1': 1, 's6': 2, 's2': 1, 's3': 1, 's4': 1, 's5': 1})
                    #print("key ==> " + str(switch))
                    if switch in switch_dict:
                        switch_dict[switch] += 1
                    else:
                        switch_dict[switch] = 1
                    #print("value ==> " + str(switch_dict[switch]))

                    if(switch_dict[switch] > self.max_num_repeated_switch_hops):
                        print("ERROR: A switch is more visited than the maximum allowed !")
                        sys.exit()

                    # check vicinity's next hop (next_switch)
                    if next_switch in neighbors_intfs.values():
                        neighbor_port = self.topo.node_to_node_port_num(switch, next_switch) #Gets the number of the port of *node1* that is connected to *node2*.
                        print("neighbor_port ==> ", neighbor_port)
                        control = self.controllers[curr_switch]
                        subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)

                        register_name = "NH"
                        #print('register_name ==> ' + str(register_name))
                        #control.register_write('NH', curr_path_index, neighbor_port)
                        control.register_write(register_name, curr_path_index, neighbor_port)

                # set switch id register
                control = self.controllers[curr_switch]
                swId=curr_switch[1:]
                #print('swId ==> ' + swId)
                control.register_write('swIdReg', 0, swId)
                
                curr_hop += 1
            curr_hop = 0
            curr_path_index += 1
            
        #reset curent path index - in case I need to manipulate it later
        curr_path_index = 0


    def dijkstra(self, failures=None):
        """Compute shortest paths and distances.

        Args:
            failures (list(tuple(str, str))): List of failed links.

        Returns:
            tuple(dict, dict): First dict: distances, second: paths.
        """
        graph = self.topo

        if failures is not None:
            graph = graph.copy()
            for failure in failures:
                graph.remove_edge(*failure)

        # Compute the shortest paths from switches to hosts.
        dijkstra = dict(all_pairs_dijkstra(graph, weight='weight'))

        distances = {node: data[0] for node, data in dijkstra.items()}
        paths = {node: data[1] for node, data in dijkstra.items()}

        return distances, paths


    def apply_alternative_rules(self, failed_links=None):
        #failed_links = [('s5', 's1')] #TODO - if it finds 's1-s5' incorrectly, force it to return the opposite: 's5-s1' - for example.
        print("failed_links ==> ", failed_links)

        curr_path_index = 0
        found = False
        node1 = 0
        node2 = 0
        for path in self.primary_paths:
            for idx_path, sw_path in enumerate(path):
                #print("curr_path_index ==> " + str(curr_path_index))

                # install route rules at the registers            
                if idx_path + 1 < len(path):
                    curr_sw_path = path[idx_path]
                    next_sw_path = path[idx_path+1]
                    print("link_path ","(",curr_sw_path, "Next ->", next_sw_path, ")")

                    for idx_failure, sw_failure in enumerate(failed_links):
                        curr_sw_failure = str(sw_failure[0])
                        next_sw_failure = str(sw_failure[1])

                        print("failure_link ","(",curr_sw_failure, "Next ->", next_sw_failure, ")")

                        if curr_sw_path == curr_sw_failure and next_sw_path == next_sw_failure:
                            print("It's a match!")
                            found = True

                            #get the path indexes where the failure occurred
                            #print("idx_path 0: ", idx_path)
                            #print("idx_path 1: ", idx_path+1)
                            node1 = idx_path
                            node2 = idx_path + 1

                            k_shortest_paths = list(shortest_simple_paths(self.topo, path[node1], path[node2])) # it is already ordered
                            
                            #iterate the k_shortest path and get the smallest (ignoring the trivial "(node1, node2)")
                            size_link = 2
                            k_path = []
                            for k in k_shortest_paths:
                                if len(k) > size_link:
                                    k_path = k
                                    break

                            print("chosen path: ", k_path)

                            #then, alter the primary path accordingly
                            #TODO
                            print("before: ", path)
                            path.pop(node1)
                            path.pop(node1)
                            print("after pop: ", path)
                            for k in reversed(k_path):
                                path.insert(node1, k)
                            print("after insert", path)

                            #install primary routes again
                            self.install_primary_entries()
        return found



    def install_rerouting_rules(self):
        #start a mirroring session at the depot (to received cloned packets)
        control = self.controllers[self.depot]
        REPORT_MIRROR_SESSION_ID = 500
        control.mirroring_add(REPORT_MIRROR_SESSION_ID, 7)

        with open('CONTROLLER_DELAY_MS.txt', 'r+', 0o777) as cp_delay:
            control_delay = cp_delay.read()

        #get packet fields after sniffing
        old_count_pkts = 0
        count_pkts = 0
        #iface = "s1-cpu-eth1"
        iface = "s60-eth1"
        #while True:
        capture = sniff(iface=iface, count=1)
        print("got it!")
        count_pkts = capture[len(capture)-1][PathHops].num_pkts
        start_cp = datetime.now()
        
        #if the older counter is less than the current counter value, there is a new incoming notification (controller packet)
        if old_count_pkts < count_pkts:
            old_count_pkts = count_pkts
            print("num packets ==> ", count_pkts)
            failures = self.check_all_links() #Returns a lst(tuple(str, str)) of DOWN links - if any...
            is_a_match = self.apply_alternative_rules(failed_links=failures)
            if is_a_match:
                print("yeap")
            else:
                failures = [(t[1], t[0]) for t in failures]
                print("nope: ", failures)
                self.apply_alternative_rules(failed_links=failures)

        end_cp = datetime.now()
        print("start_cp: ", start_cp.microsecond)
        print("end_cp: ", end_cp.microsecond)
        total_cp = end_cp - start_cp
        print("Total time CP: ", total_cp.microseconds, "us")

        control = self.controllers[self.depot]
        #capture[len(capture)-1].show2()
        #start_dp = control.register_read('tempo1_experimento_Reg', 0)
        start_dp = capture[len(capture)-1][PathHops].pkt_timestamp
        print("start_dp: ", start_dp, "us")
        #start_dp2 = control.register_read('tempo1_experimento_Reg', 0)
        #print("start_dp2: ", start_dp2, "us")

        #send response to data plane and get end_dp
        pkt = Ether() / IP(proto=0x45, ttl=128) / PathHops(path_id=0, pkt_id=0)
        sendp(pkt, iface=iface, verbose=False)

        print("Sleeping for 5 seconds...")
        sleep(5)
        end_dp = control.register_read('tempo2_experimento_Reg', 0)

        print("end_dp: ", end_dp, "us")
        total_dp = end_dp - start_dp
        #total_dp2 = end_dp - start_dp2
        print("Total time DP: ", total_dp, "us")

        with open('Patcher_v0_time_no-sleep_'+str(control_delay)+'ms.txt', 'a+', 0o777) as sys.stdout:
            failed_links = self.check_all_links()
            print(total_dp, self.maxTimeOut, control_delay, failed_links[0][0], failed_links[0][1], total_cp.microseconds)
        sys.stdout = sys.__stdout__ # reset stout to its original flow


                                        

    def failure_notification(self, failures):
        """Called if a link fails.
        Args:
            failures (list(tuple(str, str))): List of failed links.
        """
        for sw_name, controller in self.controllers.items():
            self.controllers[sw_name].table_clear("ipv4_lpm")
        self.route(failures)  



    def get_host_net(self, host):
        """Return ip and subnet of a host.

        Args:
            host (str): The host for which the net will be returned.

        Returns:
            str: IP and subnet in the format "address/mask".
        """
        gateway = self.topo.get_host_gateway_name(host)
        return self.topo.get_intfs()[host][gateway]['ip']


    # this function will be held by the CLI later... For it is a static entry: "fail s2 s3"
    #def do_fail(self, line=""):
    def do_fail(self, line): 
        """Fail a link between two nodes.

        Usage: fail_link node1 node2
        """
        try:
            node1, node2 = line.split()
            link = (node1, node2)
        except ValueError:
            print("Provide exactly two arguments: node1 node2")
            return

        for node in (node1, node2):
            if node not in self.controllers:
                print("%s is not a valid node!" % node, \
                    "You can only fail links between switches")
                return

        if node2 not in self.topo.get_intfs()[node1]:
            print("The link %s-%s does not exist." % link)
            return

        failed_links = self.check_all_links()
        for failed_link in failed_links:
            if failed_link in [(node1, node2), (node2, node1)]:
                print("The link %s-%s is already down!" % (node1, node2))
                return

        print("Failing link %s-%s." % link)

        self.update_interfaces(link, "down")
        #self.update_linkstate(link, "down")


    def check_all_links(self):
        """Check the state for all link interfaces."""
        failed_links = []
        switchgraph = self.controller.topo.subgraph(
            list(self.controller.controllers.keys())
        )
        for link in switchgraph.edges:
            if1, if2 = self.get_interfaces(link)
            if not (self.if_up(if1) and self.if_up(if2)):
                failed_links.append(link)
        return failed_links

    # this function will be held by the CLI later...
    def update_interfaces(self, link, state):
        """Set both interfaces on link to state (up or down)."""
        if1, if2 = self.get_interfaces(link)
        self.update_if(if1, state)
        self.update_if(if2, state)
        #print('link: ' + str(link))
        #print('if1: ' + str(if1) + ' if2: ' + str(if2))


    # this function will be held by the CLI later...
    def check_all_links(self):
        """Check the state for all link interfaces."""
        failed_links = []
        switchgraph = self.topo.subgraph(
            list(self.controllers.keys())
        )
        for link in switchgraph.edges:
            if1, if2 = self.get_interfaces(link)
            if not (self.if_up(if1) and self.if_up(if2)):
                failed_links.append(link)
        return failed_links


    # this function will be held by the CLI later...
    def get_interfaces(self, link):
        """Return tuple of interfaces on both sides of the link."""
        node1, node2 = link
        if_12 = self.topo.get_intfs()[node1][node2]['intfName']
        if_21 = self.topo.get_intfs()[node2][node1]['intfName']
        return if_12, if_21


    # this function will be held by the CLI later...
    @staticmethod
    def if_up(interface):
        """Return True if interface is up, else False."""
        cmd = ["ip", "link", "show", "dev", interface]
        return b"state UP" in subprocess.check_output(cmd)


    # this function will be held by the CLI later...
    @staticmethod
    def update_if(interface, state):
        """Set interface to state (up or down)."""
        print("Set interface '%s' to '%s'." % (interface, state))
        cmd = ["sudo", "ip", "link", "set", "dev", interface, state]
        subprocess.check_call(cmd)


def handle_pkt(pkt):
        print("got a packet")
        #pkt.show2()
        pkt[PathHops]
        sys.stdout.flush()

if __name__ == "__main__":
    controller = RerouteController()  # pylint: disable=invalid-name
    #CLI(controller)
