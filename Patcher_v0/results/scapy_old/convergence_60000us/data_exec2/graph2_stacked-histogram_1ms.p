set terminal eps enhanced
set output 'graph2_STACKED_AVG.eps'

set style data histograms
set style histogram rowstacked
set key above
set grid y
set xlabel 'Controller Delay (ms)'
set ylabel 'Time (us)'
#set style histogram cluster gap 1
#set style fill pattern border -1
set style fill solid 1.0 border -1
set yrange[150000:*]


set lt 1 lc rgb 'red'
set lt 2 lc rgb 'orange-red'
set lt 3 lc rgb 'orange'
set lt 4 lc rgb 'yellow'
set lt 5 lc rgb 'green'
set lt 6 lc rgb 'blue'
set lt 7 lc rgb 'dark-blue'
set lt 8 lc rgb 'violet'

plot 'Patcher_v0_time_no-sleep_stacked_AVG.txt' using 3 t 'Controller Delay (us)', \
'' using 4 title 'Overhead', \
'' using 2:xtic(1) title 'Threshold (us)'
