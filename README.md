# 基于Verilog和SPI的读SD卡方法
使用Verilog编写的SD卡初始化模块、SD读模块、SD卡模型（支持初始化响应和读数据响应），采用SPI协议，数据来自PC上的txt文件，模拟真实过程中通过SPI向SD卡请求数据的过程。

文件说明：
1. SD_r_v1.0存放了为Verilog代码，其中sd_model为SD卡模型（用于仿真，可以成功响应初始化和读数据操作，数据来自PC上的txt文件，存放在xsim文件夹内，工程内提供一个用于测试的数据）sd_init为初始化代码，sd_read为读单个扇区代码，sd_read16为连续读16个扇区代码（专门为高光谱数据开发，16个扇区刚好存放空间大小为64*64的高光谱图像的单个波段数据），test_sd为测试代码，创建工程并将代码和数据放到合适的文件夹就可以跑仿真。

2. SD_r_m存放了matlab工具包，用于将mat格式的高光谱数据转换为模拟SD内数据类型的txt文件。并给出一个包含10个波段空间大小为64*64的高光谱数据（随便生成的，仅用于测试，并非实际数据）。

# Verilog-based-SD-card-reader-via-SPI
Verilog-based SD card initialization and read modules, along with an SD card functional model (supporting initialization and read responses). The design implements the SPI protocol and preloads data from a PC-based text file to simulate the real-world process of data retrieval from an SD card via SPI.

File Description：
1. SD_r_v1.0 contains Verilog code. The sd_model is the SD card model (used for simulation and can successfully respond to initialization and read data operations, with data coming from a txt file on the PC, stored in the xsim folder, and a test dataset is provided within the project). sd_init is the initialization code, sd_read is the code for reading a single sector, sd_read16 is the code for reading 16 consecutive sectors (specifically developed for hyperspectral data, as 16 sectors exactly store a single band of hyperspectral image data with a size of 64*64), and test_sd is the test code. You can run the simulation by creating the project and placing the code and data in the appropriate folders.
2. 
3. Additionally, SD_r_m contains a Matlab toolkit for converting hyperspectral data from .mat format into .txt files compatible with the SD card model, alongside a sample dataset featuring 10 bands and a spatial resolution of 64×64 that was randomly generated for testing purposes and does not represent actual data.
