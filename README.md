# uTools Wayland Fix

这是一个非官方补丁，用于修复 uTools 7.8.0 在原生 Wayland 窗口获得焦点时，
通过全局快捷键唤起会发生以下崩溃的问题：

```text
FATAL ERROR: Error::New napi_get_last_error_info
Aborted (core dumped)
```

## 原因

uTools 的 Linux 原生模块 `linux-x64.node` 在唤起窗口前通过 X11
`XOpenDisplay()`/`_NET_ACTIVE_WINDOW` 查询当前活动窗口。当活动窗口是原生
Wayland 窗口时，没有可用的 X11 Window ID；模块后续构造 N-API 对象时没有正确
处理这个状态，最终导致 Electron 主进程 `abort()`。

## 补丁

补丁仅修改 `GetNativeWorkWindow()` 内调用 `XOpenDisplay()` 的五个机器码字节：

```text
e8 a2 6f ff ff    call XOpenDisplay@plt
31 c0 90 90 90    xor eax,eax; nop; nop; nop
```

随后程序会进入厂商代码原本已有的“没有 X11 display/window”分支，向 JavaScript
返回 `undefined`。`app.asar` 保持逐字节不变，避免触发 uTools 的完整性保护。

副作用是关闭 uTools 后，焦点可能不会精确返回先前的窗口；Wayland 合成器通常会
自行选择合适的焦点窗口。

## 安装

Arch Linux 用户可从 Release 下载 `utools-wayland-bin-*.pkg.tar.zst`：

```bash
sudo pacman -U utools-wayland-bin-7.8.0-1-x86_64.pkg.tar.zst
```

Debian/Ubuntu 用户可下载补丁后的 deb：

```bash
sudo apt install ./utools-wayland_7.8.0+waylandfix1_amd64.deb
```

## 本地构建

Debian 包：

```bash
./scripts/build-deb.sh
```

Arch 包：

```bash
makepkg -sf
```

构建脚本只接受 SHA-256 匹配的官方 7.8.0 deb：

<https://open.u-tools.cn/download/utools_7.8.0_amd64.deb>

## 安全与授权

本项目与 uTools 官方无关。补丁代码采用 MIT 许可证；uTools 本体、商标及其资源
仍归原权利人所有，并受 uTools 自身许可协议约束。Release 中的二进制包由官方
安装包机械应用上述五字节补丁生成。

