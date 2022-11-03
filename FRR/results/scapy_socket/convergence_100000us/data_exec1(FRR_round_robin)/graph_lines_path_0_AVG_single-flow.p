set terminal eps enhanced
set output 'graph_LINES_AVG_path_0_single-flow.eps'

set key above
set grid y
set xlabel 'Controller Delay (ms)'
set ylabel 'Time (ms)'
set style fill solid 1.0 border -1

set lt 1 lc rgb 'red'
set lt 2 lc rgb 'orange-red'
set lt 3 lc rgb 'orange'
set lt 4 lc rgb 'yellow'
set lt 5 lc rgb 'green'
set lt 6 lc rgb 'blue'
set lt 7 lc rgb 'dark-blue'
set lt 8 lc rgb 'violet'

path=system("ls | grep -Po FRR_time_no-sleep_.*us_LINES_AVG_single-flow.txt")
plot path using ($3/1000):xtic(1) t 'Data Plane (us)' w lines
