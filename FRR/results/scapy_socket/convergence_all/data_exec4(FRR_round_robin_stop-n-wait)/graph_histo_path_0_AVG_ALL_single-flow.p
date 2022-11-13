set terminal eps enhanced font 'Times New Roman, 16'
set output 'graph_HISTO_AVG_ALL_path_0_stop-n-wait.eps'

set style data histogram
set style histogram errorbars gap 2 lw 2
set key above
set grid y
set xlabel 'Link Failure'
set ylabel 'Time (ms)'
set style fill pattern border -1
set xtics("Link #1" 0, "Link #2" 1, "Link #3" 2, "Link #4" 3, "Link #5" 4)

plot 'PASTED_10000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 10 ms' fs pattern 1 lt -1, \
	 'PASTED_20000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 20 ms' fs pattern 2 lt -1, \
	 'PASTED_30000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 30 ms' fs pattern 10 lt -1, \
	 'PASTED_40000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 40 ms' fs pattern 4 lt -1, \
	 'PASTED_50000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 50 ms' fs pattern 5 lt -1, \
	 'PASTED_60000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 60 ms' fs pattern 6 lt -1, \
	 'PASTED_70000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 70 ms' fs pattern 7 lt -1, \
	 'PASTED_80000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 80 ms' fs pattern 8 lt -1, \
	 'PASTED_90000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 90 ms' fs pattern 9 lt -1, \
	 'PASTED_100000us_AVG_single-flow.txt' using ($3/1000):4 t 'Reaction time 100 ms' fs pattern 3 lt -1
