#!/bin/bash

for (( i=0; i <10; i++ )); do
	echo "Run controller in backgroud..."
	sudo /home/p4/mininet/util/m s60 python controller.py &
	sleep 5
	echo "Inject packets..."
	sudo /home/p4/mininet/util/m h1 python send_path_id_0_multiple_packets.py &
	sleep 5
	echo "Killing controller terminal..."
	sudo pkill -f controller.py
	sleep 2
	echo "Killing packet injection..."
	sudo pkill -f send_path_id_0_multiple_packets.py	
done
