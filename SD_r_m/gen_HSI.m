%% 生成高光谱数据（测试用）

data = zeros(64,64,10);

num = 0;
for k = 1:10
    for i = 1:64
        for j = 1:64
            data(i, j, k) = num;
            num = num + 1;
        end
    end
end

save("data_test.mat", "data");