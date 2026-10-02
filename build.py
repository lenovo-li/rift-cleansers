#!/usr/bin/env python3
"""
裂界清扫者 - 一键打包脚本（跨平台）

用法：
    python build.py                    # 打包 Windows 版本
    python build.py --clean            # 清理后打包
    python build.py --no-zip           # 只导出，不打包 ZIP
"""

import argparse
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

# 配置
GODOT_PATH = r"D:\tools\Godot_v4.7.2-stable_win64_console.exe"
PROJECT_ROOT = Path(__file__).parent.resolve()
BUILD_DIR = PROJECT_ROOT / "builds"
WINDOWS_DIR = BUILD_DIR / "windows"
EXPORT_PRESET_NAME = "Windows Desktop"


def get_version():
    """从 project.godot 读取版本号"""
    project_file = PROJECT_ROOT / "project.godot"
    with open(project_file, "r", encoding="utf-8") as f:
        for line in f:
            if "config/version" in line:
                return line.split("=")[1].strip().strip('"')
    return "0.0.0"


def clean_build():
    """清理构建目录"""
    print("[1/5] 清理旧构建...")
    if WINDOWS_DIR.exists():
        shutil.rmtree(WINDOWS_DIR)
    WINDOWS_DIR.mkdir(parents=True, exist_ok=True)


def check_dependencies():
    """检查依赖"""
    print("[2/5] 检查依赖...")

    if not Path(GODOT_PATH).exists():
        print(f"[错误] 找不到 Godot: {GODOT_PATH}")
        print("请修改脚本中的 GODOT_PATH")
        return False

    # 检查 ice_servers.json
    ice_file = PROJECT_ROOT / "ice_servers.json"
    if ice_file.exists():
        print("[提示] 检测到 ice_servers.json，将一起打包")
    else:
        print("[警告] 未找到 ice_servers.json")
        print("[警告] P2P 联机在对称 NAT 环境可能失败")

    return True


def export_game():
    """导出游戏"""
    print("[3/5] 导出 Windows 版本...")

    cmd = [
        GODOT_PATH,
        "--headless",
        "--path", str(PROJECT_ROOT),
        "--export-release", EXPORT_PRESET_NAME
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")

    if result.returncode != 0:
        print("[错误] 导出失败:")
        print(result.stdout)
        print(result.stderr)
        return False

    print("[完成] 导出成功")
    return True


def verify_files():
    """验证必需文件"""
    print("[4/5] 检查文件完整性...")

    required_files = ["Survive.exe", "Survive.pck"]
    missing = []

    for filename in required_files:
        if not (WINDOWS_DIR / filename).exists():
            missing.append(filename)

    if missing:
        print(f"[错误] 缺少文件: {', '.join(missing)}")
        return False

    # 检查 WebRTC DLL
    webrtc_dll = WINDOWS_DIR / "libwebrtc_native.windows.template_release.x86_64.dll"
    if not webrtc_dll.exists():
        print("[警告] 缺少 WebRTC 插件 DLL，P2P 联机将无法使用")
        print("[提示] 请从 addons/webrtc_native/bin/ 手动复制")

    return True


def create_zip():
    """创建 ZIP 包"""
    print("[5/5] 打包 ZIP...")

    version = get_version()
    zip_name = f"Survive-v{version}-Windows-x64.zip"
    zip_path = BUILD_DIR / zip_name

    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in WINDOWS_DIR.rglob("*"):
            if file.is_file():
                arcname = file.relative_to(WINDOWS_DIR)
                zf.write(file, arcname)

    size_mb = zip_path.stat().st_size / (1024 * 1024)

    print("\n" + "=" * 50)
    print("   打包完成！")
    print("=" * 50)
    print(f"\n版本: {version}")
    print(f"输出目录: {BUILD_DIR}")
    print(f"ZIP 文件: {zip_name}")
    print(f"文件大小: {size_mb:.1f} MB")
    print("\n[文件列表]")
    for file in sorted(WINDOWS_DIR.iterdir()):
        if file.is_file():
            print(f"  - {file.name}")

    print("\n[下一步]")
    print(f"1. 把 {zip_name} 发给朋友")
    print("2. 解压后双击 Survive.exe 运行")
    print("3. P2P 联机需要双方都有相同版本")

    return True


def main():
    parser = argparse.ArgumentParser(description="裂界清扫者一键打包脚本")
    parser.add_argument("--clean", action="store_true", help="强制清理旧构建")
    parser.add_argument("--no-zip", action="store_true", help="只导出，不打包 ZIP")
    args = parser.parse_args()

    print("=" * 50)
    print("   裂界清扫者 - 一键打包脚本")
    print("=" * 50)
    print()

    version = get_version()
    print(f"[信息] 当前版本: {version}\n")

    # 执行打包流程
    clean_build()

    if not check_dependencies():
        return 1

    if not export_game():
        return 1

    if not verify_files():
        return 1

    if not args.no_zip:
        if not create_zip():
            return 1

    print("\n打包流程完成！")
    return 0


if __name__ == "__main__":
    sys.exit(main())
