set terminal eps enhanced
set output 'graph_HISTO_AVG_ALL_path_0.eps'

set style data histogram
set key above
set grid y
set xlabel 'Link Failure'
set ylabel 'Time (us)'
set style histogram cluster gap 1
set style fill pattern border -1

plot 'FRR_time_no-sleep_10000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 10 us' fs pattern 1 lt -1, \
     'FRR_time_no-sleep_20000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 20 us' fs pattern 2 lt -1, \
     'FRR_time_no-sleep_30000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 30 us' fs pattern 10 lt -1, \
     'FRR_time_no-sleep_40000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 40 us' fs pattern 4 lt -1, \
     'FRR_time_no-sleep_50000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 50 us' fs pattern 5 lt -1, \
     'FRR_time_no-sleep_60000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 60 us' fs pattern 6 lt -1, \
     'FRR_time_no-sleep_70000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 70 us' fs pattern 7 lt -1, \
     'FRR_time_no-sleep_80000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 80 us' fs pattern 8 lt -1, \
     'FRR_time_no-sleep_90000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 90 us' fs pattern 9 lt -1, \
     'FRR_time_no-sleep_100000us_LINES_AVG_single-flow.txt' using ($3/1000):xtic(1) t 'Reaction time 100 us' fs pattern 3 lt -1