#!/bin/bash

A=('s1' 's2' 's3' 's4' 's5')
for ((j=0; j<${#A[@]}-1; j++)); do
	echo ${A[j]}
	echo ${A[j+1]}
	echo 
done