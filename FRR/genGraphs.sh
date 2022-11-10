#!/bin/bash

VERSION_EXEC=5
SINGLE_OR_TWO_FLOWS="single-flow"
FRR_VERSION="FRR_round_robin_stop-n-wait_s1s5_two_flows"
LINES_OR_OTHER="LINES"
B=('s1' 's2' 's3' 's4' 's5' 's1')
A=('s1' 's2' 's3' 's4' 's5')
C=('s1' 's5')
#TIME_OUTS="10000 20000 30000 40000 50000 60000 70000 80000 90000 100000"
TIME_OUTS="50000 60000 70000 80000 90000 100000"

#create dirs
for threshold in $TIME_OUTS; do
	echo "Create data exec version directory - if it does not exists..."
	mkdir -p results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/ #create data exec directory
	mkdir -p results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/ #create aux directory
done

#move execution files to aux dir
echo "Moving execution files to 'aux' directory..."
for threshold in $TIME_OUTS; do
	for ((j=0; j<${#B[@]}-1; j++)); do
		if [[ ${B[j]} == 's5' && ${B[j+1]} == 's1' ]]; then #invert last case, because the controller "check_all_links" function doesn't do that...
			mv FRR_time_no-sleep_${B[j+1]}-${B[j]}_${threshold}us.txt results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/
		else
			mv FRR_time_no-sleep_${B[j]}-${B[j+1]}_${threshold}us.txt results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/
		fi
	done
done

#copy scripts to aux dir and execute it
for threshold in $TIME_OUTS; do
	echo "Copying generation script to execution files - if it does not exists in the folder..."
	cp -R -u -p /home/p4/git/master_degree_p4_unipampa/FRR/getAvg_two_flows_LINES.py results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/
	echo "Writing AVG results to aggregated file..."
	cd results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/
	
	#write results into an aggregated file
	for ((j=0; j<${#B[@]}-1; j++)); do
		if [[ ${B[j]} == 's5' && ${B[j+1]} == 's1' ]]; then
			python getAvg_two_flows_LINES.py ${threshold} ${B[j+1]} ${B[j]} >> ../FRR_time_no-sleep_${threshold}us_LINES_AVG_${SINGLE_OR_TWO_FLOWS}.txt
		else
			python getAvg_two_flows_LINES.py ${threshold} ${B[j]} ${B[j+1]} >> ../FRR_time_no-sleep_${threshold}us_LINES_AVG_${SINGLE_OR_TWO_FLOWS}.txt
		fi
	done
	cd /home/p4/git/master_degree_p4_unipampa/FRR
done

#create convergence all dir for the execution
if [[ ${LINES_OR_OTHER} == "LINES" ]]; then
	echo "Copying aggregated files to convergence_all"
	mkdir -p results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/
	for threshold in $TIME_OUTS; do
		cp -R -u -p /home/p4/git/master_degree_p4_unipampa/FRR/results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/FRR_time_no-sleep_${threshold}us_${LINES_OR_OTHER}_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
		/home/p4/git/master_degree_p4_unipampa/FRR/results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/
	done
fi


#get stats from gnuplot and write into a file "STATS_..."
for threshold in $TIME_OUTS; do
    for ((j=0; j<${#B[@]}-1; j++)); do
        echo "node 1: ${B[j]}, node 2: ${B[j+1]}"
        if [[ ${B[j]} == 's5' && ${B[j+1]} == 's1' ]]; then
            gnuplot -persist <<-EOFMarker
                set print "results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}(${FRR_VERSION})/aux/STATS_${B[j+1]}-${B[j]}_${threshold}us.txt"
                stats "results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}(${FRR_VERSION})/aux/FRR_time_no-sleep_${B[j+1]}-${B[j]}_${threshold}us.txt" u (\$1/1000) name "STATS"
EOFMarker
        else
            gnuplot -persist <<-EOFMarker
                set print "/home/p4/git/master_degree_p4_unipampa/FRR/results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}(${FRR_VERSION})/aux/STATS_${B[j]}-${B[j+1]}_${threshold}us.txt"
                stats "/home/p4/git/master_degree_p4_unipampa/FRR/results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}(${FRR_VERSION})/aux/FRR_time_no-sleep_${B[j]}-${B[j+1]}_${threshold}us.txt" u (\$1/1000) name "STATS"
EOFMarker
        fi
    done
done
# rest of script, after gnuplot exits

echo "RUNNING..."



#stats
for threshold in $TIME_OUTS; do
    for ((j=0; j<${#B[@]}-1; j++)); do
        echo "STD_VAR: ${STD_VAR}"
        if [[ ${B[j]} == 's5' && ${B[j+1]} == 's1' ]]; then
            STD_VAR=$(cat results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/STATS_${B[j+1]}-${B[j]}_${threshold}us.txt | grep -P "(?<=stddev_y).*\d+" | cut -f2)
            echo "${B[j+1]}-${B[j]} ${STD_VAR}" >> results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_${LINES_OR_OTHER}_AVG_${SINGLE_OR_TWO_FLOWS}.txt
        else
            STD_VAR=$(cat results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/aux/STATS_${B[j]}-${B[j+1]}_${threshold}us.txt | grep -P "(?<=stddev_y).*\d+" | cut -f2)
            echo "${B[j]}-${B[j+1]} ${STD_VAR}" >> results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_${LINES_OR_OTHER}_AVG_${SINGLE_OR_TWO_FLOWS}.txt
        fi
    done
done

#create convergence all dir for the execution
if [[ ${LINES_OR_OTHER} == "LINES" ]]; then
    echo "Copying aggregated stats to convergence_all"
    mkdir -p results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/
    for threshold in $TIME_OUTS; do
        cp -R -u -p results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_${LINES_OR_OTHER}_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
        results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    done
fi


#aggregated mean and stddev_y
for threshold in $TIME_OUTS; do
    paste results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/FRR_time_no-sleep_${threshold}us_LINES_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
    results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
    > results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    AWK_VAR=$(awk '{printf ("%s %d %d %f\n", $1, $2, $3, $6)}' results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt)
    echo "${AWK_VAR}"
    echo "${AWK_VAR}" > results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    echo
done