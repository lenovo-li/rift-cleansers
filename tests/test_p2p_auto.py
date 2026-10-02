"""P2P 自动化测试：测试 WebRTC 连接（直连和 TURN 中转）。

用法:
  python tests/test_p2p_auto.py                # 测试直连（STUN）
  python tests/test_p2p_auto.py --relay-only   # 测试 TURN 中转（需要 ice_servers.json）
  python tests/test_p2p_auto.py --godot D:/tools/Godot.exe
"""
import argparse
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GODOT = r"D:\tools\Godot_v4.7.2-stable_win64_console.exe"


def main():
    ap = argparse.ArgumentParser(description="P2P 自动化测试")
    ap.add_argument("--godot", default=DEFAULT_GODOT, help="Godot 可执行文件路径")
    ap.add_argument("--relay-only", action="store_true", help="强制走 TURN 中转（验证 ice_servers.json）")
    ap.add_argument("--timeout", type=int, default=30, help="连接超时秒数")
    opt = ap.parse_args()

    if opt.relay_only:
        ice_path = os.path.join(ROOT, "ice_servers.json")
        if not os.path.exists(ice_path):
            print("FAIL: --relay-only 需要 ice_servers.json")
            return 1
        print("测试模式: TURN 中转（relay-only）")
    else:
        print("测试模式: 直连（STUN）")

    tmp = tempfile.mkdtemp(prefix="p2p_test_")
    sig_dir = os.path.join(tmp, "signal").replace("\\", "/")

    host_log = os.path.join(tmp, "host.log")
    client_log = os.path.join(tmp, "client.log")

    relay_flag = ["--relay-only"] if opt.relay_only else []

    print("启动房主...")
    host_cmd = [opt.godot, "--headless", "--path", ROOT, "--script", "res://tests/p2p_loopback.gd",
                "--", "--p2p-dir=" + sig_dir] + relay_flag
    with open(host_log, "w", encoding="utf-8") as f:
        host_proc = subprocess.Popen(host_cmd, stdout=f, stderr=subprocess.STDOUT)

    print("等待 %d 秒连接..." % opt.timeout)
    try:
        exit_code = host_proc.wait(timeout=opt.timeout)
    except subprocess.TimeoutExpired:
        host_proc.kill()
        host_proc.wait()
        print("FAIL: 连接超时")
        print_logs(host_log, None, tmp)
        return 1

    # 读取日志判断结果
    with open(host_log, encoding="utf-8", errors="replace") as f:
        output = f.read()

    if "结果: PASS" in output:
        print("PASS: 测试通过")
        print_summary(output)
        return 0
    else:
        print("FAIL: 测试失败")
        print_logs(host_log, None, tmp)
        return 1


def print_summary(output):
    for line in output.split("\n"):
        if "候选" in line or "连接建立" in line or "结果:" in line:
            print("  " + line.strip())


def print_logs(host_log, client_log, tmp):
    print("\n=== 房主日志 ===")
    with open(host_log, encoding="utf-8", errors="replace") as f:
        for line in f:
            print("  " + line.rstrip())
    if client_log and os.path.exists(client_log):
        print("\n=== 客户端日志 ===")
        with open(client_log, encoding="utf-8", errors="replace") as f:
            for line in f:
                print("  " + line.rstrip())
    print("\n日志目录:", tmp)


if __name__ == "__main__":
    sys.exit(main())
