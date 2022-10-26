#!/bin/bash

MAX_ITER=30
echo "Killing PREVIOUS controller terminal..."
sudo pkill -f controller.py
echo "Killing PREVIOUS packet injection..."
sudo pkill -f send_path_id_0_multiple_packets.py
echo "Killing PREVIOUS incoming packets at 'h2'"
sudo pkill -f receive.py

for (( i=1; i <=$MAX_ITER; i++ )); do
	#echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	echo "Run controller in backgroud..."
	python controller.py &
	echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	sleep 1
	echo "Wait for incoming packets at 'h2'"
	sudo /home/p4/mininet/util/m h2 python receive.py &
	sleep 1
	echo "Inject packets..."
	sudo /home/p4/mininet/util/m h1 python send_path_id_0_multiple_packets.py &
	echo "----------------------------------------ITERATION $i/$MAX_ITER----------------------------------------"
	sleep 4
	echo "Killing controller terminal..."
	sudo pkill -f controller.py
	echo "Killing packet injection..."
	sudo pkill -f send_path_id_0_multiple_packets.py
	echo "Killing incoming packets at 'h2'"
	sudo pkill -f receive.py	
done

#give file permissions to user
sudo chown $USER FRR_time_no-sleep*
