# 配置整理说明

本目录记录整理决策。

- 原 `pkgs/gnome-rounded-blur/rounded_blur_build.sh` 是上游面向传统发行版的安装脚本，不参与当前 NixOS flake 求值；整理后不再放入配置目录，原文件仍保留在执行脚本时创建的备份目录中。
