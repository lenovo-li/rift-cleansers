"""并行跑多局 sim_full_run.gd，汇总每个角色的胜率、平均存活时间、等级和击杀（数值平衡用）。
用法（项目根目录）：
  python tests/sim_batch.py --chars iron_guard,elementalist --seeds 1-6 [--jobs 12] [--extra "--map=frost"]
单局结果写在 <tmp>/sim_batch/<角色>_<种子>.log。
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

GODOT = os.environ.get("GODOT", "D:/tools/Godot_v4.7.2-stable_win64_console.exe")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
END_RE = re.compile(r"\[full\] END victory=(\w+) reason=(.*) time=(\d+)s level=(\d+)")
KILLS_RE = re.compile(r"kills=(\d+)")


def parse_seeds(text):
    if "-" in text:
        a, b = text.split("-")
        return list(range(int(a), int(b) + 1))
    return [int(s) for s in text.split(",")]


def run_one(char, seed, extra, out_dir):
    log = os.path.join(out_dir, "%s_%d.log" % (char, seed))
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "--script", "res://tests/sim_full_run.gd",
           "--", "--seed=%d" % seed, "--char=%s" % char] + extra
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=1800)
    text = open(log, encoding="utf-8", errors="replace").read()
    m = END_RE.search(text)
    kills = KILLS_RE.findall(text)
    if not m:
        return {"char": char, "seed": seed, "ok": False}
    return {"char": char, "seed": seed, "ok": True, "victory": m.group(1) == "true", "reason": m.group(2),
            "time": int(m.group(3)), "level": int(m.group(4)), "kills": int(kills[-1]) if kills else 0}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", default="iron_guard,elementalist")
    ap.add_argument("--seeds", default="1-6")
    ap.add_argument("--jobs", type=int, default=12)
    ap.add_argument("--extra", default="")
    args = ap.parse_args()
    out_dir = os.path.join(tempfile.gettempdir(), "sim_batch")
    os.makedirs(out_dir, exist_ok=True)
    extra = args.extra.split() if args.extra else []
    tasks = [(c, s) for c in args.chars.split(",") for s in parse_seeds(args.seeds)]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda t: run_one(t[0], t[1], extra, out_dir), tasks))
    failed = False
    for char in args.chars.split(","):
        rows = [r for r in results if r["char"] == char]
        done = [r for r in rows if r["ok"]]
        for r in rows:
            if r["ok"]:
                print("  %-13s seed=%-3d %s t=%3ds Lv%-2d kills=%-5d %s" % (char, r["seed"],
                      "WIN " if r["victory"] else "LOSE", r["time"], r["level"], r["kills"], r["reason"]))
            else:
                print("  %-13s seed=%-3d ERROR（没有 END 行，见日志）" % (char, r["seed"]))
                failed = True
        if done:
            wins = sum(1 for r in done if r["victory"])
            avg = lambda k: sum(r[k] for r in done) / len(done)
            print("%-13s win %d/%d  avg time %.0fs  level %.1f  kills %.0f" % (
                char, wins, len(done), avg("time"), avg("level"), avg("kills")))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
