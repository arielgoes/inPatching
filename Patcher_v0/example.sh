#!/bin/bash

trap '' INT #ignore SIGINT - i.e., Ctrl + C

foo () (
   trap - INT # DO NOT ignore SIGINT - i.e., Ctrl + C
   echo 'foo starts'
   sleep 5
   echo 'foo returns'
)

foo
echo 'main shell here'
foo
echo 'main shell exits'