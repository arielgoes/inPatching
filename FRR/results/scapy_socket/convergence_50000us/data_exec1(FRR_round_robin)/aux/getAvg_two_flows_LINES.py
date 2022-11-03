import sys

if len(sys.argv) < 4:
	print("Please, insert the argments as follow: <maxTimeOut> <node1> <node2>")
	sys.exit()
maxTimeOut=sys.argv[1]	
node1=sys.argv[2]
node2=sys.argv[3]

with open('FRR_time_no-sleep_'+str(node1)+'-'+str(node2)+'_'+str(maxTimeOut)+'us'+'.txt', 'r', 0o777) as file:
	sum_col_0_avg = 0
	sum_col_1_avg = 0
	sum_col_2_avg = 0
	n_samples=0
	for line in file:
		line = line.split()
		sum_col_0_avg += int(line[0]) 
		sum_col_1_avg += int(line[1])
		sum_col_2_avg += int(line[2])
		n_samples += 1
	float(sum_col_0_avg)
	float(sum_col_1_avg)
	float(sum_col_2_avg)
	sum_col_0_avg /= n_samples
	sum_col_1_avg /= n_samples
	sum_col_2_avg /= n_samples
	print(node1+"-"+node2, sum_col_2_avg, sum_col_0_avg, sum_col_1_avg)

