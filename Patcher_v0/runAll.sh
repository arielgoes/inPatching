#!/bin/bash

MAX_ITER=5
echo "Killing PREVIOUS controller terminal..."
sudo pkill -f controller.py
echo "Killing PREVIOUS packet injection..."
sudo pkill -f send_socket_path_id_0_multiple_packets.py

for (( i=1; i <=$MAX_ITER; i++ )); do
	#echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	echo "Run controller in backgroud..."
	sudo /home/p4/mininet/util/m s60 python controller.py &
	echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	sleep 1
	echo "Inject packets..."
	#sudo /home/p4/mininet/util/m h1 python send_path_id_0_multiple_packets.py &
	sudo /home/p4/mininet/util/m h1 python send_socket_path_id_0_multiple_packets.py & 
	echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	sleep 7
	echo "Killing controller terminal..."
	sudo pkill -f controller.py
	echo "Killing packet injection..."
	sudo pkill -f send_socket_path_id_0_multiple_packets.py
	sleep 1
done

#give file permissions to user
sudo chown $USER Patcher_v0_time*
