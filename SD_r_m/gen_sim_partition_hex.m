%% 高光谱数据（仅取5个波段用于快速调试）转换为FPGA仿真用的Hex文件
% 设计者：Lillia
% 维度要求: [169, 4096] (169个波段，每个波段4096个像素)
% 数据类型: uint16

%% 加载原始数据
% 数据说明：hydice数据集的最大值为10375，可以用16位（2字节）来表示
load('data_test.mat');
data = data(:,:,1:5);

%% 设置参数
[xx,yy,L] = size(data);
pixel_num = xx * yy;
filename = 'data_5band.txt';
fid = fopen(filename, 'w');

fprintf('正在生成文件: %s...\n', filename);

%% 转换与写入
% SD按字节存储，一个16bit像素需要拆成两个字节
for k = 1:5
    for i = 1:xx
        for j = 1:yy
            pixel = data(i,j,k);
            u16_pixel = typecast(int16(pixel), 'uint16');

            % 拆分高低字节 (大端模式：高字节在前)
            pixel_h = bitshift(u16_pixel, -8); % 右移8位(向右移8位)
            pixel_l = bitand(u16_pixel, 255);  % 取低8位(按位与0x00ff)
            
            % 以十六进制格式写入，每行一个字节
            fprintf(fid, '%02X\n', pixel_h);
            fprintf(fid, '%02X\n', pixel_l);
        end
    end
end

fclose(fid);
fprintf('生成成功！总字节数: %d\n', 5 * xx *yy * 2);