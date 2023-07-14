set terminal pngcairo
set output "sample.png"

set boxwidth 0.75 relative
set style fill pattern 0 border
set style histogram rowstacked
set style data histograms
set key above
set style fill solid 1.0 border -1
set xlabel 'Controller Delay (ms)'
set ylabel 'Total Time (%)'
set yrange [0:110]

set macros
scale = '100/(column(2)+column(3)+column(4))'

set bars 2.0
plot 'Patcher_v0_time_no-sleep_stacked_AVG_stddev.txt' using ($2 * @scale):xtic(1) t "Reaction time (timeout) (\%)" fs pattern 9 lt -1, \
     '' using ($3 * @scale) t "Control plane processing time (\%)" fs pattern 8 lt -1, \
     '' using ($4 * @scale) t "Communication time (\%)" fs pattern 6 lt -1,\
     '' using 0:(100):($5 * @scale) with errorbars notitle lw 2 lt -1