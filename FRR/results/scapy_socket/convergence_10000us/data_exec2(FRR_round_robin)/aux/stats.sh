#!/bin/bash
VAR=$(gnuplot -persist <<-EOF
    #set print "output.txt"
    stats "FRR_time_no-sleep_s1-s2_10000us.txt" u (\$1/1000) name "STATS"
EOF)
# rest of script, after gnuplot exits

echo "RUNNING..."
