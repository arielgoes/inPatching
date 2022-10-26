import sys

if len(sys.argv) < 2:
	print("Please, insert the control delay in ms: e.g., 1, 5, 10, 15,...")
	sys.exit()
num_arg=sys.argv[1]

with open("Patcher_v0_time_no-sleep_" + str(num_arg) + "ms.txt", "r") as file:
	#sum_col_0_avg = 0
	sum_col_1_avg = 0
	sum_col_5_avg = 0
	sum_col_6_avg = 0 # this column will be generated
	n_samples=0
	for line in file:
		line = line.split()
		print(line[0])
		#sum_col_0_avg += int(line[0])
		sum_col_1_avg += int(line[1])
		sum_col_5_avg += int(line[5])
		sum_col_6_avg += (int(line[0]) - int(line[1]) - int(line[5]))
		n_samples += 1
	#float(sum_col_0_avg)
	float(sum_col_1_avg)
	float(sum_col_5_avg)
	float(sum_col_6_avg)
	#sum_col_0_avg /= n_samples
	sum_col_1_avg /= n_samples
	sum_col_5_avg /= n_samples
	sum_col_6_avg /= n_samples
	#print('sum_col_0_avg:', sum_col_0_avg)
	#print('sum_col_1_avg:', sum_col_1_avg)
	#print('sum_col_5_avg:', sum_col_5_avg)
	#print('sum_col_6_avg:', sum_col_6_avg)
	print(num_arg, sum_col_1_avg, sum_col_5_avg, sum_col_6_avg)


