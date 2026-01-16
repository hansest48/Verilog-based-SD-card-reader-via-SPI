i = 1426;
j = -2;

u16_i = typecast(int16(i),'uint16');
u16_i_h = bitshift(s16_i, -8);
u16_i_l = bitand(s16_i, 255);
fprintf("%d转换为hex为：0x%02X%02X\n", i, u16_i_h, u16_i_l);

u16_j = typecast(int16(j),'uint16');
u16_j_h = uint8(bitshift(u16_j, -8));
u16_j_l = bitand(u16_j, 255);
fprintf("%d转换为hex为：0x%02X%02X\n", j, u16_j_h, u16_j_l);

