%% 获取数据集的最大值，用于确定数据位宽

%% 加载原始数据
load('data_test.mat');

[max_val, linear_idx] = max(data(:));
[x, y, z] = ind2sub(size(data), linear_idx);

fprintf('数据集的最大值为：%d，在(%d, %d, %d)处。\n', max_val, x, y, z);

[min_val, linear_idx] = min(data(:));
[x, y, z] = ind2sub(size(data), linear_idx);

fprintf('数据集的最小值为：%d，在(%d, %d, %d)处。\n', min_val, x, y, z);