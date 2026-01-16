# 基于Verilog和SPI的读SD卡方法
使用Verilog编写的SD卡初始化模块、SD读模块、SD卡模型（支持初始化响应和读数据响应），采用SPI协议，数据来自PC上的txt文件，模拟真实过程中通过SPI向SD卡请求数据的过程。

文件说明：
1. SD_r为VIVADO2020.1工程，其中sd_model为SD卡模型（用于仿真，可以成功响应初始化和读数据操作，数据来自PC上的txt文件，存放在xsim文件夹内，工程内提供一个用于测试的数据）sd_init为初始化代码，sd_read为读单个扇区代码，sd_read16为连续读16个扇区代码（专门为高光谱数据开发，16个扇区刚好存放空间大小为64*64的高光谱图像的单个波段数据）

2. SD_r_m内存放了matlab工具包，用于将mat格式的高光谱数据转换为模拟SD内数据类型的txt文件。并给出一个包含10个波段空间大小为64*64的高光谱数据（随便生成的，仅用于测试，并非实际数据）。

# Verilog-based-SD-card-reader-via-SPI
Verilog-based SD card initialization and read modules, along with an SD card functional model (supporting initialization and read responses). The design implements the SPI protocol and preloads data from a PC-based text file to simulate the real-world process of data retrieval from an SD card via SPI.

File Description：
1. SD_r is a Vivado 2020.1 project featuring the sd_model SD card functional model for simulation, which successfully responds to initialization and read operations using data sourced from .txt files in the xsim folder, with test data included in the project. This project provides sd_init for initialization, sd_read for single-sector reading, and sd_read16 for continuous reading of 16 sectors, specifically optimized for hyperspectral data as 16 sectors perfectly accommodate a single band of a 64×64 hyperspectral image. 

2. Additionally, SD_r_m contains a Matlab toolkit for converting hyperspectral data from .mat format into .txt files compatible with the SD card model, alongside a sample dataset featuring 10 bands and a spatial resolution of 64×64 that was randomly generated for testing purposes and does not represent actual data.
