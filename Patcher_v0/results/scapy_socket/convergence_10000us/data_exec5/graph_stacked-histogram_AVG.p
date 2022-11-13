set terminal eps enhanced font 'Times New Roman, 18'
set output 'graph_CP_STACKED_AVG.eps'

set style data histograms
set style histogram rowstacked
set key above vertical maxrows 3
set grid y
set xlabel 'Controller Delay (ms)'
set ylabel 'Time (ms)'
#set style histogram cluster gap 1
#set style fill pattern border -1
set style fill solid 1.0 border -1


set lt 1 lc rgb 'red'
set lt 2 lc rgb 'orange-red'
set lt 3 lc rgb 'orange'
set lt 4 lc rgb 'yellow'
set lt 5 lc rgb 'green'
set lt 6 lc rgb 'blue'
set lt 7 lc rgb 'dark-blue'
set lt 8 lc rgb 'violet'

plot 'Patcher_v0_time_no-sleep_stacked_AVG.txt' using ($4/1000) title 'Communication time (ms)' fs pattern 6 lt -1, \
'' using ($3/1000) t 'Control plane processing time (ms)' fs pattern 8 lt -1, \
'' using ($2/1000):xtic(1) title 'Reaction time (time out) (ms)' fs pattern 9 lt -1

