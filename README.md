# 解决TAD_Sim编译失败问题


**TAD_Sim 编译分为以下 2 个部分：**
- desktop (非 display 以外的所有模块)
- display

当前仅支持编译desktop,方式为基于Dockerfile镜像

# 使用方法
## 1、克隆本仓库
```bash
https://github.com/TonyFMl/Build-TAD_SIM.git
```
## 2、开始编译
```bash
./build.sh
```
* 编译持续时间较长，编译过程日志可查看TAD_Sim/log.txt