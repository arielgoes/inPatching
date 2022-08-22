from p4utils.mininetlib.network_API import NetworkAPI

net = NetworkAPI()
net.setLogLevel('info')

#add P4 switches
#net.addP4Switch('s1', cli_input='s1-commands.txt')
#net.addP4Switch('s2', cli_input='s2-commands.txt')
#net.addP4Switch('s3', cli_input='s3-commands.txt')
#net.addP4Switch('s4', cli_input='s4-commands.txt')
#net.addP4Switch('s5', cli_input='s5-commands.txt')
#net.addP4Switch('s6', cli_input='s6-commands.txt')
#net.addP4Switch('s7', cli_input='s7-commands.txt')

net.addP4Switch('s1')
net.addP4Switch('s2')
net.addP4Switch('s3')
net.addP4Switch('s4')
net.addP4Switch('s5')
net.addP4Switch('s6')
net.addP4Switch('s7')

#add hosts
net.addHost('h1')
net.addHost('h2')

#add P4 source file into the P4 switches
net.setP4SourceAll('p4src/fast_reroute.p4')

#set the links
net.addLink('h1', 's1')
net.addLink('s1', 's2')
net.addLink('s1', 's6')
net.addLink('s1', 's7')
net.addLink('s2', 's3')
net.addLink('s2', 's6')
net.addLink('s3', 's4')
net.addLink('s4', 's5')
net.addLink('s4', 's6')
net.addLink('s5', 's6')
net.addLink('s5', 's7')

net.addLink('h2', 's1')


#set interface port numbers
net.setIntfPort('h1', 's1', 1)  # Set the number of the port on h1 facing s1
net.setIntfPort('s1', 'h1', 1)  # Set the number of the port on s1 facing h1
net.setIntfPort('s1', 's2', 2)  # Set the number of the port on s1 facing s2
net.setIntfPort('s1', 's6', 3)  # Set the number of the port on s1 facing s6
net.setIntfPort('s6', 's1', 4)  # Set the number of the port on s6 facing s1
net.setIntfPort('s1', 's7', 4)  # Set the number of the port on s1 facing s7
net.setIntfPort('s7', 's1', 1)  # Set the number of the port on s7 facing s1
net.setIntfPort('s2', 's1', 1)  # Set the number of the port on s2 facing s1
net.setIntfPort('s2', 's3', 2)  # Set the number of the port on s2 facing s3
net.setIntfPort('s3', 's2', 1)  # ...
net.setIntfPort('s3', 's4', 2)  # ...
net.setIntfPort('s4', 's3', 2)  # ...
net.setIntfPort('s4', 's5', 3)  # ...
net.setIntfPort('s5', 's4', 3)  # ...
net.setIntfPort('s5', 's6', 2)  # ...
net.setIntfPort('s6', 's5', 3)  # ...
net.setIntfPort('s5', 's7', 1)  # ...
net.setIntfPort('s7', 's5', 2)  # ...

net.setIntfPort('h2', 's1', 5)  # Set the number of the port on h1 facing s1
net.setIntfPort('s1', 'h2', 5)  # Set the number of the port on s1 facing h1


#set IPs - e.g., using 'net.l2()', which is an automated strategy
net.mixed()

#set interface MAC address
net.setIntfMac('h1', 's1', '00:00:0a:00:00:11')  # Set the MAC address on h1 interface facing s1
net.setIntfMac('s1', 'h1', '00:00:0b:00:11:00')
net.setIntfMac('s1', 's2', '00:00:0b:00:11:22')
net.setIntfMac('s2', 's1', '00:00:0b:00:22:11')
net.setIntfMac('s1', 's6', '00:00:0b:00:11:66')
net.setIntfMac('s6', 's1', '00:00:0b:00:66:11')
net.setIntfMac('s1', 's7', '00:00:0b:00:11:77')
net.setIntfMac('s7', 's1', '00:00:0b:00:77:11')
net.setIntfMac('s2', 's6', '00:00:0b:00:22:66')
net.setIntfMac('s6', 's2', '00:00:0b:00:66:22')
net.setIntfMac('s2', 's3', '00:00:0b:00:22:33')
net.setIntfMac('s3', 's2', '00:00:0b:00:33:22')
net.setIntfMac('s3', 's4', '00:00:0b:00:33:44')
net.setIntfMac('s4', 's3', '00:00:0b:00:44:33')
net.setIntfMac('s4', 's6', '00:00:0b:00:44:66')
net.setIntfMac('s6', 's4', '00:00:0b:00:66:44')
net.setIntfMac('s4', 's5', '00:00:0b:00:44:55')
net.setIntfMac('s5', 's4', '00:00:0b:00:55:44')
net.setIntfMac('s5', 's6', '00:00:0b:00:55:66')
net.setIntfMac('s6', 's5', '00:00:0b:00:66:55')
net.setIntfMac('s5', 's7', '00:00:0b:00:55:77')
net.setIntfMac('s7', 's5', '00:00:0b:00:77:55')

net.setIntfMac('h1', 's1', '00:00:0a:00:00:22')  # Set the MAC address on h2 interface facing s1
net.setIntfMac('s1', 'h1', '00:00:0b:00:22:00')

#Instead of switch table entries, these entries will be held by a controller (e.g., controller.py)

net.auto_gw_arp = True
net.auto_arp_tables = True

# Nodes general options
net.disablePcapDumpAll()
net.enableLogAll()
net.enableCli()
net.startNetwork()
