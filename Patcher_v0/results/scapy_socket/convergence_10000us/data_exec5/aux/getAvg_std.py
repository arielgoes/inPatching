import sys
import math

if len(sys.argv) < 2:
    print("Please, insert the control delay in ms: e.g., 1, 5, 10, 15,...")
    sys.exit()
num_arg = sys.argv[1]

with open("Patcher_v0_time_no-sleep_" + str(num_arg) + "ms.txt", "r", 0o777) as file:
    sum_col_1_avg = 0
    sum_col_5_avg = 0
    sum_col_6_avg = 0  # this column will be generated
    n_samples = 0
    data = []
    
    for line in file:
        line = line.split()
        sum_col_1_avg += int(line[1])
        sum_col_5_avg += int(line[5])
        sum_col_6_avg += (int(line[0]) - int(line[1]) - int(line[5]))
        n_samples += 1
        data.append([int(line[0]), int(line[1]), int(line[5])])

    sum_col_1_avg /= n_samples
    sum_col_5_avg /= n_samples
    sum_col_6_avg /= n_samples
    
    stddev = math.sqrt(sum((entry[0] - entry[1] - entry[2] - sum_col_6_avg) ** 2 for entry in data) / n_samples)
    
    print(num_arg, sum_col_1_avg, sum_col_5_avg, sum_col_6_avg, stddev)
