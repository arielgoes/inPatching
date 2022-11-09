#!/bin/bash

echo "Sending a bunch of packets..."

sudo /home/p4/mininet/util/m h1 python snd-rcv_scripts/send_socket_path_id_0_multiple_packets.py &
sudo /home/p4/mininet/util/m h1 python snd-rcv_scripts/send_socket_path_id_1_multiple_packets.py &

sleep 15
echo "Killing..."
sudo pkill -f send_socket_path_id_0_multiple_packets.py
sudo pkill -f send_socket_path_id_1_multiple_packets.py