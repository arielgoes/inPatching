"""A central controller computing and installing shortest paths.

In case of a link failure, paths are recomputed.
"""

import os
#from cli import CLI
from re import search
from random import random
from networkx.algorithms import all_pairs_dijkstra

from p4utils.utils.helper import load_topo
from p4utils.utils.topology import *
from p4utils.utils.sswitch_thrift_API import SimpleSwitchThriftAPI
from collections import defaultdict


# this function will be held by the CLI later...
import subprocess



class RerouteController(object):
    """Controller for the fast rerouting exercise."""

    def __init__(self):
        """Initializes the topology and data structures."""

        if not os.path.exists('topology.json'):
            print("Could not find topology object!\n")
            raise Exception


        self.primary_paths = [['s1', 's2', 's3', 's4', 's5', 's6', 's1'], ['s1', 's2', 's6', 's4', 's5', 's7', 's1']] # manual path for now... (to send packets, one must specify the switch IDs - not the ports)
        self.primary_probability = []
        self.depot = self.primary_paths[0][0]
        #print("depot ==>", self.depot)


        self.topo = load_topo('topology.json')
        self.controllers = {}
        self.connect_to_switches()
        self.reset_states()
        self.install_primary_source_routing_entries()
        self.failed_links = [['s1', 's2']]
        self.install_secondary_source_routing_entries(failed_links=self.failed_links)

        #reseting every link state (e.g., link states that are currently 'down' become 'up' once again.)
        self.do_reset(line="s1 s2")

        # Fail link
        self.do_fail(line="s1 s2")


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


    def install_primary_source_routing_entries(self):
        flag = True
        for lst in self.primary_paths:
            print()
            print("-------------------- Current Path --------------------")
            for index, switch in enumerate(lst):
                if self.depot in switch and flag: # install IPv4 rule (only once)
                    for host in self.topo.get_hosts():
                        if 'h1' in host:
                            subnet = self.get_host_net(host) #returns: "10.1.1.2/24" in this case
                            #print('subnet ==>',subnet)
                            host_mac = self.topo.get_host_mac(host)
                            host_mac = "00:00:0a:00:00:11"

                            depot_control = self.controllers['s1']
                            #print('s1 control ==>', control)
                            
                            # normal forwarding (ivp4)
                            print("(", self.depot,  "ipv4_lpm )")
                            depot_control.table_add(table_name='ipv4_lpm', action_name='ipv4_forward', match_keys=[str(subnet)], action_params=[host_mac, '1']) # remember to change this port if depot is changed
                            flag = False #unset ipv4 flow-rule flag

                # install source routing rules            
                if index + 1 < len(lst):
                    curr_switch = lst[index]
                    next_switch = lst[index+1]
                    print("(",curr_switch, "Next ->", next_switch, ")")

                    # get neighbors
                    neighbors_intfs = self.topo.get_interfaces_to_node(curr_switch)
                    #print("neighbors_intfs =>", neighbors_intfs) # print output: intf => {'s1-eth1': 'h1', 's1-eth2': 's2', 's1-eth3': 's6', 's1-eth4': 's7'}

                    # check vicinity's next hop (next_switch)
                    if next_switch in neighbors_intfs.values():
                        neighbor_port = self.topo.node_to_node_port_num(switch, next_switch) #Gets the number of the port of *node1* that is connected to *node2*.
                        control = self.controllers[curr_switch]
                        control.table_add('device_to_port', 'ipv4_forward', match_keys=[str(next_switch[1])], action_params=['ff:ff:ff:ff:ff:ff', str(neighbor_port)])       
        #return path


    # this method does not cover host link failure
    def install_secondary_source_routing_entries(self, failed_links):
        #TODO
        #print("get intfs s1 ==>", self.topo.get_intfs()['s1']['h1']['intfName'])
        #print(self.topo.get_all_paths_between_nodes('s1', 's2'))

        alternative_paths_between_two_neighbours = []

        # remove all failed_links
        for si, sj in failed_links:
            alternative_paths_between_two_neighbours=self.topo.get_all_paths_between_nodes(si,sj)
            for path in reversed(alternative_paths_between_two_neighbours):
                if len(path) == 2:
                    alternative_paths_between_two_neighbours.remove(path)

        #print(alternative_paths_between_two_neighbours)
        if len(alternative_paths_between_two_neighbours) == 0:
            print("There is not an alternative path for this link failure!")
            return

        alt_path = list(alternative_paths_between_two_neighbours[0])
        #print(alt_path)

        print("---------- Installing secondary rules ----------")

        for index, switch in enumerate(alt_path):
            if index + 1 < len(alt_path):
                curr_switch = alt_path[index]
                next_switch = alt_path[index+1]

                # get neighbors
                neighbors_intfs = self.topo.get_interfaces_to_node(curr_switch)
                #print("neighbors_intfs =>", neighbors_intfs) # print output: intf => {'s1-eth1': 'h1', 's1-eth2': 's2', 's1-eth3': 's6', 's1-eth4': 's7'}

                # check vicinity's next hop (next_switch)
                if next_switch in neighbors_intfs.values():
                    neighbor_port = self.topo.node_to_node_port_num(switch, next_switch) #Gets the number of the port of *node1* that is connected to *node2*.
                    control = self.controllers[curr_switch]
                    control.table_add('device_to_port', 'ipv4_forward', match_keys=[str(next_switch[1])], action_params=['ff:ff:ff:ff:ff:ff', str(neighbor_port)])








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


    # this function will be held by the CLI later...
    def update_interfaces(self, link, state):
        """Set both interfaces on link to state (up or down)."""
        if1, if2 = self.get_interfaces(link)
        self.update_if(if1, state)
        self.update_if(if2, state)


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

if __name__ == "__main__":
    controller = RerouteController()  # pylint: disable=invalid-name
    #CLI(controller)
