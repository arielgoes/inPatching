set terminal eps enhanced
set output 'graph_HISTO_AVG_ALL_path_0.eps'

set style data histogram
set style histogram errorbars gap 1 lw 1
set key above
set grid y
set xlabel 'Link Failure'
set ylabel 'Time (us)'
set style fill pattern border -1

plot 'PASTED_10000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 10 us' fs pattern 1 lt -1, \
	 'PASTED_20000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 20 us' fs pattern 2 lt -1, \
	 'PASTED_30000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 30 us' fs pattern 10 lt -1, \
	 'PASTED_40000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 40 us' fs pattern 4 lt -1, \
	 'PASTED_50000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 50 us' fs pattern 5 lt -1, \
	 'PASTED_60000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 60 us' fs pattern 6 lt -1, \
	 'PASTED_70000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 70 us' fs pattern 7 lt -1, \
	 'PASTED_80000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 80 us' fs pattern 8 lt -1, \
	 'PASTED_90000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 90 us' fs pattern 9 lt -1, \
	 'PASTED_100000us_AVG_single-flow.txt' using 3:4:xtic(1) t 'Reaction time 100 us' fs pattern 3 lt -1