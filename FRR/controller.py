"""A central controller computing and installing shortest paths.

In case of a link failure, paths are recomputed.
"""

import os
import sys
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

        #self.primary_paths = [['s1', 's2', 's3', 's4', 's5', 's6', 's1'], ['s1', 's2', 's6', 's4', 's5', 's7', 's1']] # manual path for now... (to send packets, one must specify the switch IDs - not the ports)
        self.primary_paths = [['s1', 's2', 's3', 's4', 's5', 's6', 's1']]
        self.alternative_paths = [['s1', 's6', 's2', 's3', 's4', 's5', 's6', 's1']]
        self.maxTimeOut = 3000000 #3000000us = 3000ms = 3sec
        self.depot = self.primary_paths[0][0]
        self.max_num_repeated_switch_hops = 2
        #print("depot ==>", self.depot)

        self.topo = load_topo('topology.json')
        self.controllers = {}
        self.connect_to_switches()
        self.reset_states()
        print("PRIMARY ENTRIES")
        self.install_primary_entries()
        #self.failed_links = [['s1', 's2']]
        #print("ALTERNATIVE ENTRIES")
        #self.install_alternative_entries(failed_links=self.failed_links)
        

        #reseting every link state (e.g., link states that are currently 'down' become 'up' once again.)
        self.do_reset(line="s1 s2")

        #Fail link
        #self.do_fail(line="s1 s2")


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
        """Install the mapping from prefix to nexthop ids for all switches."""

        #save the depot switch id into a register for further operations
        control = self.controllers[self.depot]
        control.register_write('depotIdReg', 0, self.depot[1:])

        #set the max time out for further operations
        control.register_write('maxTimeOutDepotReg', 0, self.maxTimeOut)

        #set depot (only one port for all the probe paths - for now)
        neighbors_intfs = self.topo.get_interfaces_to_node(self.depot)
        #print("neighbors_intfs (host) ==> ", neighbors_intfs)
        if 'h2' in neighbors_intfs.values(): #if the switch is connect to the host, the switch is the depot
            depot_port = self.topo.node_to_node_port_num('h2', self.depot)
            control = self.controllers[self.depot]
            control.register_write('depotPort', 0, depot_port) #register_write(register_name, index, value)
            #sys.exit() # force exit (debugging)


        curr_path_index = 0
        for lst in self.primary_paths:
            print("-------------------- Current Path (PRIMARY) --------------------")
            #print("curr_path_index ==> ", curr_path_index)
            #print("len curr path ==> ", len(lst))

            #store the max length of the current path in a register for logic operations (in the P4 code)
            print("..... primary path max size:")
            visited = []
            for dummy, switch in enumerate(lst): #dummy is a filler variable - not used
                print('--' + str(switch) + '--')
                control = self.controllers[switch]
                control.register_write('lenPrimaryPathSize', curr_path_index, len(lst))
                # I also need to add a table entry because I have a metadata I use for other cases (meta.indexPath) - for now:
                subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)
                if switch not in visited:
                    control.table_add('len_primary_path', 'read_len_primary_path', match_keys=[str(curr_path_index)], action_params=[str(curr_path_index)]) #match_keys=[str(0)] -> is.alt == 0, i.e., PRIMARY PATH
                visited.append(switch)

                #reset all 'alternativeNH' entries to -1 (because 0 may be used for loop ports and we don't want this misunderstanding)
                for i in range(self.max_num_repeated_switch_hops):
                    register_name = "primaryNH_" + str(i+1)
                    print("register_name (reseting) ==> " + str(register_name))
                    control.register_write(register_name, curr_path_index, 9999)

            print()

            print("..... route rules")
            switch_dict = defaultdict()
            curr_hop = 1
            for index, switch in enumerate(lst):

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
                    print("key ==> " + str(switch))
                    if switch in switch_dict:
                        switch_dict[switch] += 1
                    else:
                        switch_dict[switch] = 1
                    print("value ==> " + str(switch_dict[switch]))

                    if(switch_dict[switch] > self.max_num_repeated_switch_hops):
                        print("ERROR: A switch is more visited than the maximum allowed !")
                        sys.exit()

                    # check vicinity's next hop (next_switch)
                    if next_switch in neighbors_intfs.values():
                        neighbor_port = self.topo.node_to_node_port_num(switch, next_switch) #Gets the number of the port of *node1* that is connected to *node2*.
                        print("neighbor_port ==> ", neighbor_port)
                        control = self.controllers[curr_switch]
                        subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)

                        register_name = "primaryNH_" + str(switch_dict[switch])
                        print('register_name ==> ' + str(register_name))
                        #control.register_write('primaryNH', curr_path_index, neighbor_port)
                        control.register_write(register_name, curr_path_index, neighbor_port)

                        #print('curr_hop: ==> ', curr_hop)
                        
                        table_name = "primary_path_exact_" + str(switch_dict[switch])
                        print("table name ==> " + str(table_name))
                        action_name = "read_primary_port_" + str(switch_dict[switch])
                        print("action_name ==> " + str(action_name))
                        #control.table_add('primary_path_exact', 'read_primary_port', match_keys=[str(curr_hop)], action_params=[str(curr_path_index)])
                        control.table_add(table_name, action_name, match_keys=[str(curr_hop)], action_params=[str(curr_path_index)])
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




    def install_alternative_entries(self, failed_links):
        """Install the mapping from prefix to nexthop ids for all switches."""

        #save the depot switch id into a register for further operations
        #control = self.controllers[self.depot]
        #control.register_write('depotIdReg', 0, self.depot[1:])

        #set the max time out for further operations
        #control.register_write('maxTimeOutDepotReg', 0, self.maxTimeOut)

        #set depot (only one port for all the probe paths - for now)
        #neighbors_intfs = self.topo.get_interfaces_to_node(self.depot)
        #print("neighbors_intfs (host) ==> ", neighbors_intfs)
        #if 'h2' in neighbors_intfs.values(): #if the switch is connect to the host, the switch is the depot
        #    depot_port = self.topo.node_to_node_port_num('h2', self.depot)
        #    control = self.controllers[self.depot]
        #    control.register_write('depotPort', 0, depot_port) #register_write(register_name, index, value)
            #sys.exit() # force exit (debugging)

        curr_path_index = 0
        for lst in self.alternative_paths:
            print("-------------------- Current Path (ALTERNATIVE) --------------------")
            #print("curr_path_index ==> ", curr_path_index)
            #print("len curr path ==> ", len(lst))

            #store the max length of the current path in a register for logic operations (in the P4 code)
            print("..... alternative path max size:")
            visited = []
            for dummy, switch in enumerate(lst): #dummy is a filler variable - not used
                print('--' + str(switch) + '--')
                control = self.controllers[switch]
                control.register_write('lenAlternativePathSize', curr_path_index, len(lst))
                # I also need to add a table entry because I have a metadata I use for other cases (meta.indexPath) - for now:
                subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)
                if switch not in visited:
                    control.table_add('len_alternative_path', 'read_len_alternative_path', match_keys=[str(curr_path_index)], action_params=[str(curr_path_index)]) #match_keys=[str(1)] -> is.alt == 1, i.e., ALTERNATIVE PATH
                visited.append(switch)

                #reset all 'alternativeNH' entries to -1 (because 0 may be used for loop ports and we don't want this misunderstanding)
                for i in range(self.max_num_repeated_switch_hops):
                    register_name = "alternativeNH_" + str(i+1)
                    print("register_name (reseting) ==> " + str(register_name))
                    control.register_write(register_name, curr_path_index, 9999)

            print()

            print("..... route rules")
            switch_dict = defaultdict()
            curr_hop = 1
            for index, switch in enumerate(lst):
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
                    if switch in switch_dict:
                        switch_dict[switch] += 1
                    else:
                        switch_dict[switch] = 1
                    print(switch_dict)

                    if(switch_dict[switch] > self.max_num_repeated_switch_hops):
                        print("ERROR: A switch is more visited than the maximum allowed !")
                        sys.exit()

                    # check vicinity's next hop (next_switch)
                    if next_switch in neighbors_intfs.values():
                        neighbor_port = self.topo.node_to_node_port_num(switch, next_switch) #Gets the number of the port of *node1* that is connected to *node2*.
                        print("neighbor_port ==> ", neighbor_port)
                        control = self.controllers[curr_switch]
                        subnet = self.get_host_net('h2') #depot (static code - may need to be changed later - in the case of more hosts are added)
                        
                        register_name = "alternativeNH_" + str(switch_dict[switch])
                        print('register_name ==> ' + str(register_name))
                        #control.register_write('alternativeNH', curr_path_index, neighbor_port)
                        control.register_write(register_name, curr_path_index, neighbor_port)

                        #print('curr_hop: ==> ', curr_hop)
                        
                        table_name = "alternative_path_exact_" + str(switch_dict[switch])
                        print("table name ==> " + str(table_name))
                        action_name = "read_alternative_port_" + str(switch_dict[switch])
                        print("action_name ==> " + str(action_name))
                        #control.table_add('alternative_path_exact', 'read_alternative_port', match_keys=[str(curr_hop)], action_params=[str(curr_path_index)])
                        control.table_add(table_name, action_name, match_keys=[str(curr_hop)], action_params=[str(curr_path_index)])
                curr_hop += 1
                # set switch id register
                #control = self.controllers[curr_switch]
                #swId=curr_switch[1:]
                #print('swId ==> ' + swId)
                #control.register_write('swIdReg', 0, swId)
            curr_hop = 0
            curr_path_index += 1
            
        #reset curent path index - in case I need to manipulate it later
        curr_path_index = 0




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

if __name__ == "__main__":
    controller = RerouteController()  # pylint: disable=invalid-name
    #CLI(controller)
