# 1080p 摄像头 + 钢球亮圆斑检测

这是独立 TD 工程，位于 `exercise/lab_hd_1_mipi_hdmi_1080p_steel_ball/`。完整复制指定 `lab_hd_1_mipi_hdmi_1080p` 参考工程的源码与 IP，加入此前钢球检测功能，并适配全分辨率检测。原 1024×600 钢球工程和原 1080p 参考工程均保留。

## 本次结果

- 新 bit 已于 2026-09-23 生成，文件头确认为 PH1P35MDG324。
- 最终日志 ERROR=0，综合后锁存器=0。建立裕量 +0.925 ns，保持裕量 +0.020 ns，STNS/HTNS 均为 0；STA coverage 96.55%。
- Slice 13986/21216、ERAM20K 49/108、DSP 36/40。
- 30 帧回归、1080p 完整帧和 FIFO 故障测试均通过。
- bit SHA-256：`53f17f7027d61c89d7b19c4c5c02a723dda59ef94f98693537b7aebc7f7b7096`。

## 打开和构建

- TD 6.2.1 打开 `td_project/camera_to_dsi_display.al`。
- 目标器件：`PH1P35MDG324`，speed 3。
- HDL、IP、约束及原自定义综合脚本全部在本目录内部；项目登记的 53 项文件引用已检查存在且没有跨出本目录。
- 最终烧写文件：`td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit`。
- 构建日志：同一目录的 `run_cli.log`。
- 完整时序报告：同一目录的 `camera_to_dsi_display_pr.timing`。
- 本次构建摘要和文件哈希：`steel_ball_verification/build_summary.json`。

PowerShell 命令行重建：

```powershell
& 'D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin/td_commands_prompt.exe' 'D:/AAAProject/FPGA/HX1P35A_Contest_202606/exercise/lab_hd_1_mipi_hdmi_1080p_steel_ball/td_project/build_steel_ball.tcl' *> 'D:/AAAProject/FPGA/HX1P35A_Contest_202606/exercise/lab_hd_1_mipi_hdmi_1080p_steel_ball/td_project/camera_to_dsi_display_Runs/phy_1/run_cli.log'
```

## 1080p 配置

| 环节 | 配置 |
|---|---|
| CS500 寄存器 | `0x3208/09 = 0x0780`（1920），`0x320A/0B = 0x0438`（1080） |
| 行帧时序 | 沿用参考工程 `HTS=0x0B24`、`VTS=0x0467`；保留曝光、增益及其他初始化值 |
| RAW → AXI | `uial2axis` 1920×1080，每拍 4 个 RAW10 像素 |
| 有效图像窗口 | `image_correction` 480 拍/行、1080 行/帧 |
| ISP | demosaic 与 AWB 均为 1920×1080 |
| DDR | 沿用参考工程四帧缓冲及 7000000 地址间隔；单帧 RGB888 为 6220800 字节，按原控制器地址步进占 3110400 地址单位，帧缓冲不重叠 |
| HDMI | 有效 1920×1080，总时序 2200×1125；HFP/HSA/HBP=88/44/148，VFP/VSA/VBP=4/5/36 |
| HDMI PLL | 沿用参考工程独立 PLL，名义像素时钟 75 MHz、串行时钟 375 MHz，约 30.3 帧/秒；这是参考工程配置，不是 1080p60 |

`design_top_wrapper.v`、`isp/isp_top.v`、`image_correction.v`、`uics500_cfg/uics500reg.v`、`hdmi_tx.v`、`video_cuttting.v` 与 SDC 的 1080p 设置来自指定参考工程。未使用 1024×600 工程的旧 HDMI 时钟约束。

## 检测支路的 1080p 适配

检测器仍在 `S_csi_rx_clk` 域镜像观察 ISP 输出。送往 DDR/HDMI 的 RGB 视频和同步信号是连续赋值直通，不加延迟、不裁剪、不叠加。

- 精确解析 MSB 优先的压紧 RGB888：连续 3 个 128 位拍恢复 5/5/6 个像素。
- 保留完整 1920×1080 逐像素检测，不降采样。
- x/y 坐标扩至 11 位，行/帧计数扩至 12 位，面积扩至 22 位、周长扩至 24 位。
- 上一行标签按 16 像素组织成一个 RAM 字。5/6 像素全暗记录一次清除对应标签并前进；含亮像素的记录逐像素做四连通域标记、根查找、合并、面积和周长统计。此优化只省略全暗块的逐像素状态机开销，不丢弃像素。
- `tuser` 可早于有效数据；原 AWB 的 `tlast` 领先最终打包输出一拍，检测支路以 `TLAST_DELAY=1` 对齐，视频直通信号不改。
- LED[0] 为 D10、LVCMOS33、高电平点亮，与官方例程及板卡原理图一致。默认连续 4 帧确认后翻转。
- 低有效复位：`I_rst_n & S_rst_n` 异步拉低、CSI 时钟同步释放。原参考工程的复位引脚仍为 R10。

圆形度使用四邻域网格周长，要求 `P² <= 24*A`，并联合面积、包围盒宽高比、填充率筛选。候选周长高位非零时直接拒绝，再计算低 16 位平方，避免无意义的大乘法；默认面积上限下，可能合格的周长远小于 65536。

## 调参

在 `user_source/hdl_source/steel_ball_detect.v` 修改默认参数，或在顶层实例覆盖，然后重新构建。

| 参数 | 默认值 | 含义 |
|---|---:|---|
| `Y_THRESHOLD` | 200 | `Y=(77R+150G+29B)>>8`，严格 `Y>200` |
| `MIN_AREA` / `MAX_AREA` | 80 / 12000 | 原始 1080p 图像中的连通域像素数 |
| `FILL_MIN_PERCENT` / `FILL_MAX_PERCENT` | 65 / 90 | 面积占包围盒面积的百分比，排除细线和实心方块 |
| `ASPECT_PERCENT` | 75 | 短边至少为长边的 75% |
| `CIRCULARITY_SCALE` | 24 | `P² <= 参数*A`，降低此值会收紧圆形度要求 |
| `CONFIRM_FRAMES` | 4 | 建议 3～5，同时控制亮/灭确认 |
| `LABEL_BITS` | 6 | 最多 63 个临时标签/帧，含后来合并的标签 |
| `FIFO_BITS` | 12 | 4096 个掩码/同步记录 |

标签耗尽或帧格式错误时，该帧无效，清除确认并关闭 LED，下一帧可恢复。FIFO 满时 `O_fault` 锁存并关闭输出，需复位；持续大量高亮可能超过串行连通域处理能力。识别对象是亮圆斑，白色圆形物体也可能满足条件，实际钢球需结合照明与曝光调参。

## 验证

运行 `steel_ball_verification/run_verification.ps1` 可复现：

1. 30 帧独立 Python 洪泛填充参考模型对比：逐个核对连通域面积、周长和包围盒，覆盖合并、跨打包边界、颜色通道、阈值边界、方块/长条、多目标、边界、标签耗尽、短行、双向四帧确认及零延迟旁路。
2. 直接实例化原 `data_96bit_to_128bit`，输入完整 1920×1080 帧，3300 CSI 时钟/行。圆斑中心 `(1800,1040)`、半径 30，越过旧 10 位坐标范围；参考面积 2821、网格周长 244。FIFO 峰值 264/4096，无溢出。
3. 小 FIFO 强制溢出、锁存故障和异步复位恢复。

日志分别为 `simulation.log`、`full_frame.log`、`fault.log`。TD 的正时序裕量仅针对现有 SDC 覆盖的路径；未增加放宽检测器时序的例外。

尚未实板烧写、摄像头实拍或 HDMI/LED 实测。上板时使用本独立工程生成的 bit，并核对 BitWriter 器件为 PH1P35MDG324。
