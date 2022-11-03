import sys

if len(sys.argv) < 3:
	print("Please, insert the link failure: e.g., 's1' 's2'")
	sys.exit()
node1=sys.argv[1]
node2=sys.argv[2]

with open('FRR_time_no-sleep_'+str(node1)+'-'+str(node2)+'.txt', 'r', 0o777) as file:
	sum_col_1_avg = 0
	sum_col_6_avg = 0 # this column will be generated
	n_samples=0
	for line in file:
		line = line.split()
		sum_col_1_avg += int(line[1])
		sum_col_6_avg += (int(line[0]) - int(line[1]))
		n_samples += 1
	float(sum_col_1_avg)
	float(sum_col_6_avg)
	sum_col_1_avg /= n_samples
	sum_col_6_avg /= n_samples
	print(node1+"-"+node2, sum_col_1_avg, sum_col_6_avg)


