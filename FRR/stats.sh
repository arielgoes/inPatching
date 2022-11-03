#!/bin/bash

B=('s1' 's2' 's3' 's4' 's5' 's1')
#B=('s1' 's2')
TIME_OUTS="10000 20000 30000 40000 50000 60000 70000 80000 90000 100000"
#TIME_OUTS="10000"
VERSION_EXEC=3
SINGLE_OR_TWO_FLOWS="SINGLE_OR_TWO_FLOWS"
FRR_VERSION="FRR_round_robin"



#create convergence all dir for the execution
if [[ ${LINES_OR_OTHER} == "LINES" ]]; then
    echo "Copying aggregated stats to convergence_all"
    mkdir -p results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/
    for threshold in $TIME_OUTS; do
        cp -R -u -p results/scapy_socket/convergence_${threshold}us/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
        results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    done
fi

