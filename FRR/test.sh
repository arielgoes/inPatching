#!/bin/bash

LINES_OR_OTHER="LINES"
VERSION_EXEC=5
SINGLE_OR_TWO_FLOWS="single-flow"
FRR_VERSION="FRR_round_robin_stop-n-wait_s1s5_one_flow"

for threshold in $TIME_OUTS; do
    paste results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/FRR_time_no-sleep_${threshold}us_LINES_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
    results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/STATS_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt \
    > results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    AWK_VAR=$(awk '{printf ("%s %d %d %f\n", $1, $2, $3, $6)}' results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt)
    echo "${AWK_VAR}"
    echo "${AWK_VAR}" > results/scapy_socket/convergence_all/data_exec${VERSION_EXEC}\(${FRR_VERSION}\)/PASTED_${threshold}us_AVG_${SINGLE_OR_TWO_FLOWS}.txt
    echo
done