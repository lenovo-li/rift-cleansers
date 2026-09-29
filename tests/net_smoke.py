"""M2 联机冒烟测试：启动主机 + 客户端两个无头 Godot 进程（都由机器人操作），
客户端中途被杀掉再用同一令牌重连，最后对比双方记录的状态。

用法: python tests/net_smoke.py [--godot 路径] [--lag 50] [--seconds 60]
--lag 是每一端的单向发送延迟（两端都加，往返约 2×lag + 本机开销）。
退出码 0 = 全部检查通过。
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GODOT = r"D:\tools\Godot_v4.7.2-stable_win64_console.exe"
PORT = 24599
TOKEN = "smoketest0001"


def launch(godot, args, log_path):
    cmd = [godot, "--headless", "--max-fps", "60", "--path", ROOT, "--"] + args
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    return subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT), log


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def nearest(history, wall):
    return min(history, key=lambda r: abs(r["wall"] - wall)) if history else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--lag", type=int, default=50)
    ap.add_argument("--seconds", type=int, default=60)
    opt = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix="net_smoke_")
    host_rep, c1_rep, c2_rep = (os.path.join(tmp, n) for n in ("host.json", "client1.json", "client2.json"))
    common = ["--bot", "--port=%d" % PORT, "--lag=%d" % opt.lag]
    kill_at, gap = opt.seconds * 0.4, 6.0

    host, hlog = launch(opt.godot, ["--host", "--name=主机", "--net-report=" + host_rep,
                                    "--quit-after=%d" % (opt.seconds + 5)] + common, os.path.join(tmp, "host.log"))
    time.sleep(3.0)
    c1, c1log = launch(opt.godot, ["--join=127.0.0.1", "--name=客户端", "--token=" + TOKEN,
                                   "--net-report=" + c1_rep] + common, os.path.join(tmp, "client1.log"))
    time.sleep(kill_at)
    c1.kill()
    c1.wait()
    disconnect_wall = time.time()
    time.sleep(gap)
    remaining = opt.seconds - kill_at - gap
    c2, c2log = launch(opt.godot, ["--join=127.0.0.1", "--name=客户端", "--token=" + TOKEN,
                                   "--net-report=" + c2_rep, "--quit-after=%d" % remaining] + common,
                       os.path.join(tmp, "client2.log"))
    c2.wait(timeout=remaining + 30)
    host.wait(timeout=60)
    for f in (hlog, c1log, c2log):
        f.close()
    return check(load(host_rep), load(c1_rep), load(c2_rep), disconnect_wall, tmp)


def check(host, c1, c2, disconnect_wall, tmp):
    fails, info = [], []

    def expect(cond, msg):
        (info if cond else fails).append(("OK   " if cond else "FAIL ") + msg)

    expect(len(host) > 10, "主机有 %d 条记录" % len(host))
    w1 = [r for r in c1 if r["welcomed"]]
    w2 = [r for r in c2 if r["welcomed"]]
    expect(len(w1) > 5 and w1[0]["slot"] == 1, "客户端 1 加入并分配到槽位 1")
    expect(len(w2) > 5 and w2[0]["slot"] == 1, "重连后客户端回到槽位 1（令牌匹配）")

    # 一致性：等级、技能、装备必须一致；敌人数和位置允许快照/延迟误差
    mism, pos_err, enemy_err = 0, [], []
    for r in w1 + w2:
        h = nearest(host, r["wall"])
        if h is None:
            continue
        if abs(h["level"] - r["level"]) > 1:
            mism += 1
        for slot, cp in r["players"].items():
            hp = h["players"].get(slot)
            if hp is None:
                continue
            if cp["skills"] != hp["skills"] or cp["equip"] != hp["equip"]:
                mism += 1
            dx, dz = cp["pos"][0] - hp["pos"][0], cp["pos"][1] - hp["pos"][1]
            pos_err.append((dx * dx + dz * dz) ** 0.5)
        if h["enemies"] > 0:
            enemy_err.append(abs(r["enemy_views"] - h["enemies"]) / h["enemies"])
    samples = len(w1) + len(w2)
    expect(mism <= max(2, samples // 10), "等级/技能/装备不一致样本 %d / %d（允许升级瞬间的少量）" % (mism, samples))
    if pos_err:
        pos_err.sort()
        expect(pos_err[len(pos_err) // 2] < 3.0, "玩家位置误差中位数 %.2f m（记录时刻不同步，允许 < 3 m）" % pos_err[len(pos_err) // 2])
    if enemy_err:
        enemy_err.sort()
        expect(enemy_err[len(enemy_err) // 2] < 0.15, "客户端敌人视图数量误差中位数 %.1f%%" % (100 * enemy_err[len(enemy_err) // 2]))

    boss_err = []
    for r in w1 + w2:
        h = nearest(host, r["wall"])
        if h and h["boss_hp"] > 0 and r["boss_hp"] > 0:
            boss_err.append(abs(h["boss_hp"] - r["boss_hp"]) / max(1.0, h["boss_hp"]))
            if h["boss_phase"] != r["boss_phase"] and abs(h["wall"] - r["wall"]) < 0.3:
                mism += 1
    if boss_err:
        boss_err.sort()
        expect(boss_err[len(boss_err) // 2] < 0.1, "Boss 血量误差中位数 %.1f%%（%d 个样本）" % (100 * boss_err[len(boss_err) // 2], len(boss_err)))
    if host and host[-1]["time"] > 540:
        expect(bool(boss_err), "Boss 登场后客户端收到 Boss 状态")

    during = [r for r in host if disconnect_wall + 1.5 < r["wall"] < disconnect_wall + 5]
    expect(any(r["players"].get("1", {}).get("ai") for r in during), "掉线期间主机把槽位 1 交给 AI 托管")
    # 只看客户端 2 在线期间（测试结束时客户端先退出，之后主机又会转为 AI 托管）
    after = [r for r in host if w2 and w2[0]["wall"] + 2 < r["wall"] < w2[-1]["wall"] - 1]
    expect(bool(after) and not any(r["players"].get("1", {}).get("ai", True) for r in after), "重连后槽位 1 恢复玩家控制")
    if w1 and w2:
        before = w1[-1]["players"].get("1", {}).get("skills", [])
        expect(sum(w2[0]["players"]["1"]["skills"]) >= sum(before), "重连后技能等级保留（%s → %s）" % (before, w2[0]["players"]["1"]["skills"]))

    pings = sorted(r["ping"] for r in w1 + w2 if r["ping"] > 0)
    errs = sorted(r["pred_error"] for r in w1 + w2)
    kb = sorted(r["kb_in"] for r in w1 + w2 if r["kb_in"] > 0)
    if pings:
        info.append("INFO 往返延迟中位数 %.0f ms" % pings[len(pings) // 2])
    if errs:
        expect(errs[len(errs) // 2] < 1.0, "客户端预测误差中位数 %.2f m" % errs[len(errs) // 2])
    if kb:
        info.append("INFO 客户端下行中位数 %.1f KB/s，最大 %.1f KB/s" % (kb[len(kb) // 2], kb[-1]))
    info.append("INFO 主机最后：t=%.0fs Lv%d 敌人 %d 击杀 %d" % (host[-1]["time"], host[-1]["level"], host[-1]["enemies"], host[-1]["kills"]) if host else "")

    for name in ("host.log", "client1.log", "client2.log"):
        with open(os.path.join(tmp, name), encoding="utf-8", errors="replace") as f:
            errors = [l.strip() for l in f if "SCRIPT ERROR" in l or "Invalid call" in l]
        expect(not errors, "%s 无脚本错误%s" % (name, "" if not errors else "：" + errors[0][:160]))

    for line in info + fails:
        print(line)
    print("日志目录:", tmp)
    print("结果:", "PASS" if not fails else "FAIL (%d)" % len(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
