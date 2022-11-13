set terminal eps enhanced font 'Times New Roman, 18'
set output 'graph_HISTO_AVG_ALL_path_cooperative.eps'

set style data histogram
set style histogram cluster gap 1 errorbars
set key above
set grid y
set xlabel 'Reaction time (ms)'
set ylabel 'Time (ms)'
set style fill pattern border -1

plot 'ALL.txt' every 3 using ($3/1000):4:xtic(2) t 'Non-cooperative {/:Italic In-Patching}' fs pattern 5 lt -1, \
'' every 3::1 using ($3/1000):4 t 'Cooperative {/:Italic In-Patching} Probe #1' fs pattern 6 lt -1, \
'' every 3::2 using($3/1000):4 t 'Cooperative {/:Italic In-Patching} Probe #2' fs pattern 2 lt -1


