from p4utils.mininetlib.network_API import NetworkAPI
#import sys

#sys.argv[1]
CONTROLLER_DELAY_MS=30

net = NetworkAPI()
net.setLogLevel('info')
#net.disableLogAll()

#add P4 switches
#net.addP4Switch('s1', cli_input='s1-commands.txt')
#net.addP4Switch('s2', cli_input='s2-commands.txt')
#net.addP4Switch('s3', cli_input='s3-commands.txt')
#net.addP4Switch('s4', cli_input='s4-commands.txt')
#net.addP4Switch('s5', cli_input='s5-commands.txt')
#net.addP4Switch('s6', cli_input='s6-commands.txt')
#net.addP4Switch('s7', cli_input='s7-commands.txt')

#primary switches
net.addP4Switch('s1')
net.addP4Switch('s2')
net.addP4Switch('s3')
net.addP4Switch('s4')
net.addP4Switch('s5')

#alternative switches
net.addP4Switch('s12')
net.addP4Switch('s23')
net.addP4Switch('s34')
net.addP4Switch('s45')
net.addP4Switch('s51')

net.addP4Switch('s60')

#add hosts
net.addHost('h1')
net.addHost('h2')

#add P4 source file into the P4 switches
net.setP4SourceAll('p4src/fast_reroute.p4')

#set the primary links
net.addLink('h1', 's1')
net.addLink('h2', 's1')
net.addLink('s1', 's2')
net.addLink('s2', 's3')
net.addLink('s3', 's4')
net.addLink('s4', 's5')
net.addLink('s5', 's1')

#set the alternative links
net.addLink('s1', 's12')
net.addLink('s12', 's2')
net.addLink('s2', 's23')
net.addLink('s23', 's3')
net.addLink('s3', 's34')
net.addLink('s34', 's4')
net.addLink('s4', 's45')
net.addLink('s45', 's5')
net.addLink('s5', 's51')
net.addLink('s51', 's1')


#set interface port numbers...

#...at hosts
net.setIntfPort('h1', 's1', 1)  # Set the number of the port on h1 facing s1
net.setIntfPort('h2', 's1', 1)  # Set the number of the port on h2 facing s1

#at s1
net.setIntfPort('s1', 's2', 1)  # Set the number of the port on s1 facing s2
net.setIntfPort('s1', 's5', 2)
net.setIntfPort('s1', 's51', 3)
net.setIntfPort('s1', 'h1', 4)
net.setIntfPort('s1', 'h2', 5)
net.setIntfPort('s1', 's12', 6)

#at s2
net.setIntfPort('s2', 's1', 1)
net.setIntfPort('s2', 's12', 2)
net.setIntfPort('s2', 's23', 3)
net.setIntfPort('s2', 's3', 4)

#at s3
net.setIntfPort('s3', 's2', 1)
net.setIntfPort('s3', 's23', 2)
net.setIntfPort('s3', 's34', 3)
net.setIntfPort('s3', 's4', 4)

#at s4
net.setIntfPort('s4', 's5', 1)
net.setIntfPort('s4', 's3', 2)
net.setIntfPort('s4', 's34', 3)
net.setIntfPort('s4', 's45', 4)

#at s5
net.setIntfPort('s5', 's1', 1)
net.setIntfPort('s5', 's4', 2)
net.setIntfPort('s5', 's45', 3)
net.setIntfPort('s5', 's51', 4)

#at s12
net.setIntfPort('s12', 's1', 1)
net.setIntfPort('s12', 's2', 2)

#at s23
net.setIntfPort('s23', 's2', 1)
net.setIntfPort('s23', 's3', 2)

#at s34
net.setIntfPort('s34', 's3', 1)
net.setIntfPort('s34', 's4', 2)

#at s45
net.setIntfPort('s45', 's4', 1)
net.setIntfPort('s45', 's5', 2)

#at s51
net.setIntfPort('s51', 's1', 1)
net.setIntfPort('s51', 's5', 2)


#set link delays
net.addLink('s1', 's60', weight=1000) #a high weight to make it less "attractive" to Dijkstra's shortest path algorithm
net.setIntfPort('s60', 's1', 1)
net.setIntfPort('s1', 's60', 7)
net.setDelay('s1', 's60', CONTROLLER_DELAY_MS)

with open('CONTROLLER_DELAY_MS.txt', 'w+', 0o777) as control_delay: #read and write mode - no append
	control_delay.write(str(CONTROLLER_DELAY_MS))

#net.setDelay('s1', 's2', 5)
#net.setDelay('s2', 's3', 5)
#net.setDelay('s3', 's4', 5)
#net.setDelay('s4', 's5', 5)
#net.setDelay('s5', 's1', 5)

#set IPs - e.g., using 'net.l2()', which is an automated strategy
net.mixed()
#net.l3()



# Nodes general options
#net.enableCpuPortAll() #enables a special interface to a controller for all switches
#net.enableCpuPort('s1') #enables a special interface to cpu/controller for a single switch
net.disablePcapDumpAll()
#net.enableLogAll()
net.enableCli()
#net.disableCli()
net.startNetwork()

