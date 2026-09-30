"""M2 联机压力测试（文档 06 退出条件「500 敌人双方 60 FPS」）：主机 + 客户端两个带渲染的进程，
主机把敌人维持在 N 只，记录双方 FPS 和客户端带宽。
用法: python tests/net_stress.py [--count 500] [--seconds 30] [--lag 50]
"""
import argparse, json, os, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"D:\tools\Godot_v4.7.2-stable_win64_console.exe"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=500)
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--lag", type=int, default=50)
    opt = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix="net_stress_")
    common = ["--bot", "--port=24598", "--lag=%d" % opt.lag, "--quit-after=%d" % opt.seconds]
    procs = []
    for role, extra in (("host", ["--host", "--stress=%d" % opt.count]), ("client", ["--join=127.0.0.1"])):
        cmd = [GODOT, "--path", ROOT, "--resolution", "1280x720", "--"] + common + extra + [
            "--net-report=" + os.path.join(tmp, role + ".json")]
        procs.append(subprocess.Popen(cmd, stdout=open(os.path.join(tmp, role + ".log"), "w"), stderr=subprocess.STDOUT))
        time.sleep(3)
    for p in procs:
        p.wait(timeout=opt.seconds + 60)
    ok = True
    for role in ("host", "client"):
        hist = json.load(open(os.path.join(tmp, role + ".json"), encoding="utf-8"))
        steady = [r for r in hist if r["enemies"] >= opt.count * 0.9][3:]  # 敌人到位后、去掉前几秒热身
        fps = sorted(r["fps"] for r in steady)
        if not fps:
            print("FAIL %s: 敌人数量没有达到 %d" % (role, opt.count)); ok = False; continue
        kb = sorted(r["kb_in"] for r in steady)
        low = fps[max(0, len(fps) // 20)]
        passed = low >= 60
        ok = ok and passed
        print("%s %s: 敌人 %d  FPS 中位数 %d  最低5%% %d  下行 %.1f KB/s" % (
            "OK  " if passed else "FAIL", role, steady[-1]["enemies"], fps[len(fps) // 2], low, kb[len(kb) // 2]))
    print("日志目录:", tmp)
    print("结果:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
