#!/bin/bash

B=('s1' 's2' 's3' 's4' 's5' 's1')
#B=('s1' 's2')
TIME_OUTS="10000 20000 30000 40000 50000 60000 70000 80000 90000 100000"
#TIME_OUTS="10000"

LINES_OR_OTHER="LINES"
VERSION_EXEC=5
SINGLE_OR_TWO_FLOWS="single-flow"
FRR_VERSION="FRR_round_robin_stop-n-wait_s1s5_two_flows"

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


