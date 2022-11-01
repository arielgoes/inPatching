set terminal eps enhanced
set output 'graph15_LINES_AVG_path_0.eps'

set key above
set grid y
set xlabel 'Link Failure'
set ylabel 'Time (us)'
set style fill solid 1.0 border -1


set lt 1 lc rgb 'red'
set lt 2 lc rgb 'orange-red'
set lt 3 lc rgb 'orange'
set lt 4 lc rgb 'yellow'
set lt 5 lc rgb 'green'
set lt 6 lc rgb 'blue'
set lt 7 lc rgb 'dark-blue'
set lt 8 lc rgb 'violet'

plot 'FRR_time_no-sleep_60000us_LINES_AVG.txt' using ($3/1000):xtic(1) t 'Reaction time 60 us' w lines, \
	 'FRR_time_no-sleep_80000us_LINES_AVG.txt' using ($3/1000):xtic(1) t 'Reaction time 80 us' w lines, \
	 'FRR_time_no-sleep_100000us_LINES_AVG.txt' using ($3/1000):xtic(1) t 'Reaction time 100 us' w lines, \
	 'FRR_time_no-sleep_120000us_LINES_AVG.txt' using ($3/1000):xtic(1) t 'Reaction time 120 us' w lines
