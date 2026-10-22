import subprocess, json
def probe(x0,y0,w,h,label):
    raw=f"/private/tmp/_q_{label}.png"; up=f"/private/tmp/_q_{label}_u.png"
    subprocess.run(["screencapture","-x","-R",f"{x0},{y0},{w},{h}",raw],check=True)
    subprocess.run(["sips","-z",str(h*4),str(w*4),raw,"--out",up],stdout=subprocess.DEVNULL,check=True)
    r=subprocess.run(["ocr",up,"--json","--lang","en-US"],capture_output=True,text=True)
    try: d=json.loads(r.stdout)
    except Exception: return []
    return sorted([(l["text"].strip(), x0+(l["x"]+l["w"]/2)*w) for l in d["lines"]], key=lambda t:t[1])
ruler = [(int(t),x) for t,x in probe(950,145,950,26,"rul") if t.isdigit()]
ch = probe(950,372,950,26,"chd")
if len(ruler) >= 2:
    b1,x1 = ruler[0]; b2,x2 = ruler[-1]
    bw = (x2-x1)/(b2-b1); bar1x = x1-(b1-1)*bw
    print(f"标尺: bar{b1}={x1:.1f}  bar{b2}={x2:.1f}  小节宽={bw:.2f}px  bar1≈{bar1x:.1f}   bar9≈{bar1x+8*bw:.1f}")
    for t,x in ch:
        if t and not t.replace('.','').isdigit():
            print(f"  {t:>8}  x={x:6.1f}  → bar {1+(x-bar1x)/bw:5.2f}")
else:
    print("标尺识别失败:", ruler)
