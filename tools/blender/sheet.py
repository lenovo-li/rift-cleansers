"""把多张预览图拼成一张对比表（系统 Python + Pillow，不在 Blender 里跑）。
用法：python tools/blender/sheet.py 输出.png 图1.png 图2.png ... [--cols 4]"""
import sys

from PIL import Image

args = sys.argv[1:]
cols = 4
if "--cols" in args:
    i = args.index("--cols")
    cols = int(args[i + 1])
    del args[i:i + 2]
out, paths = args[0], args[1:]
imgs = [Image.open(p).convert("RGB") for p in paths]
w = max(im.width for im in imgs)
h = max(im.height for im in imgs)
rows = (len(imgs) + cols - 1) // cols
sheet = Image.new("RGB", (w * min(cols, len(imgs)), h * rows), (40, 42, 50))
for i, im in enumerate(imgs):
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet.save(out)
print("[sheet] %s %dx%d" % (out, sheet.width, sheet.height))
