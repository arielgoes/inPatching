#!/bin/bash


parallel ::: "sudo python network.py" "bash runAll.sh"

#gnome-terminal -- bash runAll.sh

echo "out..."
sleep 3
sudo mn -c