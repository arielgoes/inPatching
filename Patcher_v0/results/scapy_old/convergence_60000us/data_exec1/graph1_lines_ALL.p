set terminal eps enhanced
set output 'graph1_ALL.eps'

#set style data histogram
set key above
set xlabel 'Controller Delay (ms)'
set ylabel 'Time (us)'
#set style data histogram
#set style histogram cluster gap 1
#set style fill pattern border -1

plot 'Patcher_v0_time_no-sleep_ALL.txt' using 2:xtic(1) title 'MIN' w lines lc 1, \
'' using 3:xtic(1) title 'MAX' w lines lc 2, \
'' using 4:xtic(1) title 'AVG' w lines lc 3
