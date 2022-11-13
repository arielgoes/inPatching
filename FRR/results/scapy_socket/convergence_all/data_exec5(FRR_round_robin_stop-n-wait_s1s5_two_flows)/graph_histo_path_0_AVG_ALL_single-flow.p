set terminal eps enhanced
set output 'graph_HISTO_AVG_ALL_path_0.eps'

set style data histogram
set style histogram errorbars gap 2 lw 2
set key above
set grid y
set xlabel 'Link Failure'
set ylabel 'Time (us)'
set style fill pattern border -1

plot 