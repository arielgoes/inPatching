#!/bin/bash

TIME_OUTS="50000"

gnuplot -persist <<-EOFMarker
	set print "STATS_col2_s1-s5_${TIME_OUTS}us.txt"
	stats "FRR_time_no-sleep_s1-s5_${TIME_OUTS}us.txt" u (\$2/1000)
EOFMarker

echo "s1-s5 `cat STATS_col2_s1-s5_${TIME_OUTS}us.txt | grep -P "(?<=stddev_y).*\d+" | cut -f2`" >> ../STATS_col2_${TIME_OUTS}us_LINES_AVG_single-flow.txt
awk -i inplace 'NF==2 {print $0}' STATS_col1_${TIME_OUTS}us_LINES_AVG_single-flow.txt #filter files with 2 columns (i.e., useful lines)

#send to PASTED...
#paste FRR_time_no-sleep_50000us_LINES_AVG_single-flow.txt STATS_col1_50000us_LINES_AVG_single-flow.txt STATS_col2_50000us_LINES_AVG_single-flow.txt | column -t -s $'\t' >> ../../convergence_all/data_exec5\(FRR_round_robin_stop-n-wait_s1s5_two_flows\)/PASTED_50000us_AVG_single-flow.txt 

#filter columns with awk
