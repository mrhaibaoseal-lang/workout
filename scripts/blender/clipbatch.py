"""穿模批次檢查（增量）：動作 × 系列 全部組合，輸入沒變的組直接沿用上次結果。
python scripts/blender/clipbatch.py [--moves a,b] [--series x,y] [--force] [--dry] [-j 2] [--blender 路徑]

每組的「輸入指紋」＝下列檔案內容的雜湊：
  共用：hero_proto.py、moves3d.py、gear_util.py、clipcheck.py、moves/props_*.py（骨架、身體、檢查規則都在這些檔）
  動作：該動作所在的 moves/<批次>.py
  系列：gear_<系列>.py（basic 沒有）
所以：新增／修改一個動作 → 只重跑「那個批次檔的動作 × 全部系列」；新增／修改一個系列 → 只重跑「全部動作 × 那個系列」；
改共用檔（骨架、身體、檢查規則）→ 全部重跑。
結果放 out/clipcache/<動作>__<系列>/（hero.blend、clip.json、stamp.json），總表 out/clipcache/summary.json。
只有「有穿模」的組需要人看：總表列出它們最嚴重的格，拿去截圖。

關節角度判定（2026-11-24 加，BLENDER_BRIEF §5-2）：動作的 MOVE_META 可寫 'angles'（範圍的寫法見 scripts/blender/README.md）。
  量測由 anglecheck.py 對 hero.blend 逐格量一次（每個動作只量一個系列，角度跟裝備無關），存成 angles.json；
  判定每次執行都重算（只看 angles.json 和目前的 angles 字面值，不開 Blender）。
  指紋計算時把 MOVE_META 裡的 'angles' 欄位拿掉：只改 angles 不會重跑穿模檢查，也不用重新量。
  結果：每組多一欄 summary.json 的 'angles'，並印 `[angles] 動作: PASS`／`FAIL 膝 knee.L min 62 < 70`；有 FAIL 時結束碼為 1。
"""
import argparse, ast, glob, hashlib, json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CACHE = os.path.join(ROOT, 'out', 'clipcache')
DEFAULT_BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
COMMON = ['hero_proto.py', 'moves3d.py', 'gear_util.py', 'clipcheck.py']


def strip_angles(data):
    """動作檔的位元組，MOVE_META 裡每個動作的 'angles' 值換成 {}（改角度範圍不該讓穿模檢查重跑）。沒有 MOVE_META 就原樣回傳。"""
    if b'MOVE_META' not in data: return data
    starts = [0]
    for ln in data.split(bytes([10])): starts.append(starts[-1] + len(ln) + 1)
    cuts = []
    for n in ast.parse(data.decode('utf-8')).body:
        if isinstance(n, ast.Assign) and any(getattr(t, 'id', '') == 'MOVE_META' for t in n.targets) and isinstance(n.value, ast.Dict):
            for v in n.value.values:
                if isinstance(v, ast.Dict):
                    for k2, v2 in zip(v.keys, v.values):
                        if isinstance(k2, ast.Constant) and k2.value == 'angles':   # col_offset 是 UTF-8 位元組位置
                            cuts.append((starts[v2.lineno - 1] + v2.col_offset, starts[v2.end_lineno - 1] + v2.end_col_offset))
    for a, b in sorted(cuts, reverse=True): data = data[:a] + b'{}' + data[b:]
    return data


def sha(paths):
    h = hashlib.sha256()
    for p in sorted(paths):
        h.update(os.path.relpath(p, HERE).replace(chr(92), '/').encode())
        h.update(strip_angles(open(p, 'rb').read()))
    return h.hexdigest()[:16]


def collect_meta():
    """{動作: (動作檔, MOVE_META 裡的字典)}"""
    meta = {}
    for f in sorted(glob.glob(os.path.join(HERE, 'moves', '*.py'))):
        for n in ast.parse(open(f, encoding='utf-8').read()).body:
            if isinstance(n, ast.Assign) and any(getattr(t, 'id', '') == 'MOVE_META' for t in n.targets):
                for k, v in ast.literal_eval(n.value).items():
                    meta[k] = (f, v)
    return meta


def collect_moves():
    return {k: f for k, (f, _) in collect_meta().items()}


def group_stamp(m, move_file, s):
    """一組（動作 × 系列）的輸入指紋；review_sheet.py 也用它判斷快取的 hero.blend 是不是最新的"""
    common = [os.path.join(HERE, f) for f in COMMON] + glob.glob(os.path.join(HERE, 'moves', 'props_*.py'))
    return sha(set(common + [move_file] + ([os.path.join(HERE, f'gear_{s}.py')] if s != 'basic' else [])))


def collect_series():
    return ['basic'] + sorted(os.path.basename(f)[5:-3] for f in glob.glob(os.path.join(HERE, 'gear_*.py'))
                              if not f.endswith('gear_util.py'))


def score(rep):
    """穿模對數（不含沉地板、軟墊接觸）和沉地板對數。"""
    clip = sink = 0
    for hits in rep.get('frames', {}).values():
        for k, v in hits.items():
            if k.startswith('沉'): sink += v
            elif not k.endswith('軟墊'): clip += v
    return clip, sink


def run_one(job, blender):
    move, series, stamp, d = job
    os.makedirs(d, exist_ok=True)
    env = dict(os.environ, GEAR=series, MOVE=move, QUICK='1')
    env.pop('EXPORT', None)
    t0 = time.time()
    log = open(os.path.join(d, 'log.txt'), 'w', encoding='utf-8', errors='replace')
    # 只要 hero.blend：渲染 1 格草稿（hero_proto 沒給格數會渲染 2 格）
    r = subprocess.run([blender, '-b', '-P', os.path.join(HERE, 'hero_proto.py'), '--', d, '0'],
                       env=env, stdout=log, stderr=subprocess.STDOUT)
    rep_path = os.path.join(d, 'clip.json')
    if r.returncode == 0 and os.path.exists(os.path.join(d, 'hero.blend')):
        if os.path.exists(rep_path): os.remove(rep_path)
        r = subprocess.run([blender, '-b', os.path.join(d, 'hero.blend'), '-P', os.path.join(HERE, 'clipcheck.py'),
                            '--', rep_path, '2'], stdout=log, stderr=subprocess.STDOUT)
    log.close()
    ok = r.returncode == 0 and os.path.exists(rep_path)
    res = {'move': move, 'series': series, 'stamp': stamp, 'ok': ok, 'sec': round(time.time() - t0)}
    if ok:
        rep = json.load(open(rep_path, encoding='utf-8'))
        res['clip'], res['sink'] = score(rep)
        res['worst'] = rep.get('worst', [])
        json.dump(res, open(os.path.join(d, 'stamp.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    return res

# ---------- 關節角度判定 ----------
def run_angles(job, blender):
    """對一個組的 hero.blend 量角度，存 angles.json（內含 stamp：之後用來判斷要不要重量）"""
    d, mstamp = job
    out = os.path.join(d, 'angles.json')
    if os.path.exists(out): os.remove(out)
    r = subprocess.run([blender, '-b', os.path.join(d, 'hero.blend'), '-P', os.path.join(HERE, 'anglecheck.py'), '--', out],
                       stdout=open(os.path.join(d, 'angles_log.txt'), 'w', encoding='utf-8', errors='replace'), stderr=subprocess.STDOUT)
    if r.returncode != 0 or not os.path.exists(out): return False
    m = json.load(open(out, encoding='utf-8')); m['stamp'] = mstamp
    json.dump(m, open(out, 'w', encoding='utf-8'), ensure_ascii=False)
    return True


def load_meas(d, mstamp):
    p = os.path.join(d, 'angles.json')
    if not os.path.exists(p): return None
    m = json.load(open(p, encoding='utf-8'))
    return m if m.get('stamp') == mstamp else None


def judge(meas, spec):
    """meas＝angles.json 的內容，spec＝MOVE_META 的 'angles'。回傳 (狀態, 失敗清單, 每個量的實測最小／最大)。
    spec 的寫法：{'knee': (70, 180)}＝整個循環最小值不能小於 70、最大值不能大於 180（任一邊可寫 None＝不限）；
      {'knee': {'min': (70, 90)}}＝最小值（最深）要落在 70～90 之間（也可寫 'max'，兩個都寫就兩個都檢查；可以抓「蹲不夠深」）。
    名稱不帶左右（'knee'）＝左右都檢查；帶左右（'knee.L'）只檢查那一邊；'trunk_lean' 沒有左右。"""
    TOL = 0.5   # 容差（度）：量測四捨五入、浮點誤差（例如設 5° 量到 4.999°）不算失敗
    q = meas['q']; seen = {k: (min(v), max(v)) for k, v in q.items()}
    if not spec: return '未設定', [], seen
    fails = []
    for key, rule in spec.items():
        names = [key] if key in q else [k for k in (key + '.L', key + '.R') if k in q]
        if not names: fails.append(f'沒有「{key}」這個量（可用：{sorted({k.split(".")[0] for k in q})}）'); continue
        for n in names:
            lo, hi = seen[n]
            if isinstance(rule, dict):
                for side, val in (('min', lo), ('max', hi)):
                    if side not in rule: continue
                    a, b = rule[side]
                    if (a is not None and val < a - TOL) or (b is not None and val > b + TOL):
                        fails.append(f'{n} {side} {val:.0f} 不在 [{"-" if a is None else a}, {"-" if b is None else b}]')
            else:
                a, b = rule
                if a is not None and lo < a - TOL: fails.append(f'{n} min {lo:.0f} < {a}')
                if b is not None and hi > b + TOL: fails.append(f'{n} max {hi:.0f} > {b}')
    return ('FAIL' if fails else 'PASS'), fails, seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--moves'); ap.add_argument('--series')
    ap.add_argument('--force', action='store_true', help='忽略快取全部重跑')
    ap.add_argument('--dry', action='store_true', help='只列出要跑哪些組')
    ap.add_argument('-j', type=int, default=2, help='同時跑幾個 Blender')
    ap.add_argument('--blender', default=os.environ.get('BLENDER', DEFAULT_BLENDER))
    a = ap.parse_args()

    meta = collect_meta(); allmoves = {k: f for k, (f, _) in meta.items()}
    moves = dict(allmoves); series = collect_series()
    if a.moves:
        want = a.moves.split(','); bad = [m for m in want if m not in moves]
        if bad: sys.exit(f'沒有這些動作：{bad}；可用：{sorted(moves)}')
        moves = {m: moves[m] for m in want}
    if a.series:
        want = a.series.split(','); bad = [s for s in want if s not in series]
        if bad: sys.exit(f'沒有這些系列：{bad}；可用：{series}')
        series = want

    gstamp = lambda m, s: group_stamp(m, allmoves[m], s)
    todo, cached = [], []
    for m, mf in sorted(moves.items()):
        for s in series:
            stamp = gstamp(m, s); d = os.path.join(CACHE, f'{m}__{s}')
            sp = os.path.join(d, 'stamp.json')
            old = json.load(open(sp, encoding='utf-8')) if os.path.exists(sp) else None
            if old and old.get('stamp') == stamp and not a.force: cached.append(old)
            else: todo.append((m, s, stamp, d))

    print(f'共 {len(cached) + len(todo)} 組：沿用 {len(cached)}，要跑 {len(todo)}')
    for m, s, _, _ in todo: print(f'  跑  {m} × {s}')
    if a.dry or not todo:
        results = cached
    else:
        if not os.path.exists(a.blender): sys.exit(f'找不到 Blender：{a.blender}（用 --blender 或環境變數 BLENDER 指定）')
        done = []
        with ThreadPoolExecutor(a.j) as ex:
            for r in ex.map(lambda j: run_one(j, a.blender), todo):
                done.append(r)
                tag = '失敗' if not r['ok'] else ('穿模' if r['clip'] else ('沉地' if r['sink'] else '乾淨'))
                print(f'  [{len(done)}/{len(todo)}] {r["move"]} × {r["series"]}：{tag}'
                      + (f'（{r["clip"]} 對，最嚴重格 {r["worst"]}）' if r['ok'] and r['clip'] else '')
                      + f'  {r["sec"]}s')
        results = cached + done

    # 角度：每個動作只量一個系列（角度跟裝備無關）。有一組的 angles.json 是最新的就沿用，否則挑一組有 hero.blend 的重量
    ahash = sha([os.path.join(HERE, 'anglecheck.py')])
    def mstamp_of(m, s): return gstamp(m, s) + ahash
    series_all = collect_series()
    def find_meas(m, ss):
        for s_ in ss:
            mm = load_meas(os.path.join(CACHE, f'{m}__{s_}'), mstamp_of(m, s_))
            if mm: return mm
    jobs = {}
    for m in sorted(moves):
        if find_meas(m, series): continue
        for s_ in series:
            d = os.path.join(CACHE, f'{m}__{s_}')
            if os.path.exists(os.path.join(d, 'hero.blend')):
                jobs[m] = (d, mstamp_of(m, s_)); break
    if jobs and not a.dry and os.path.exists(a.blender):
        print(f'量角度：{len(jobs)} 個動作（{", ".join(sorted(jobs))}）')
        with ThreadPoolExecutor(a.j) as ex:
            for m, ok in zip(jobs, ex.map(lambda m: run_angles(jobs[m], a.blender), list(jobs))):
                if not ok: print(f'  量角度失敗 {m}：看 {jobs[m][0]}/angles_log.txt')

    # 判定：每次都重算（不開 Blender）；所有動作（含這次沒選到的）都算，寫進總表
    verdict = {}
    for m in sorted(allmoves):
        spec = meta[m][1].get('angles')
        meas = find_meas(m, series_all)
        if meas is None: verdict[m] = {'status': '未量測', 'fails': [], 'range': {}}; continue
        st, fails, seen = judge(meas, spec)
        verdict[m] = {'status': st, 'fails': fails, 'range': {k: [round(a_, 1), round(b_, 1)] for k, (a_, b_) in seen.items()}}

    # 總表：合併快取裡所有組（包括這次沒選到的），只列需要人看的
    allres = []
    for sp in glob.glob(os.path.join(CACHE, '*', 'stamp.json')):
        allres.append(json.load(open(sp, encoding='utf-8')))
    os.makedirs(CACHE, exist_ok=True)
    for r in allres:
        r['angles'] = verdict.get(r['move'], {'status': '未量測', 'fails': [], 'range': {}})
    json.dump(sorted(allres, key=lambda r: (r['move'], r['series'])),
              open(os.path.join(CACHE, 'summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    bad = [r for r in results if not r.get('ok')]
    hot = sorted((r for r in results if r.get('ok') and (r['clip'] or r['sink'])), key=lambda r: -r['clip'])
    print(f'\n這次範圍：乾淨 {len(results) - len(bad) - len(hot)}、要看 {len(hot)}、失敗 {len(bad)}')
    for r in hot:
        print(f'  {r["move"]:14} × {r["series"]:6}  穿模 {r["clip"]:5}  沉地 {r["sink"]:4}  最嚴重格 {r["worst"]}')
    for r in bad:
        print(f'  失敗 {r["move"]} × {r["series"]}：看 out/clipcache/{r["move"]}__{r["series"]}/log.txt')
    print('\n關節角度判定（範圍來自 MOVE_META 的 angles；只列這次範圍的動作）：')
    afail = 0
    for m in sorted(moves):
        v = verdict[m]
        if v['status'] == 'FAIL':
            afail += 1; print(f'  [angles] {m}: FAIL ' + '；'.join(v['fails']))
        else: print(f'  [angles] {m}: {v["status"]}')
    sys.exit(1 if bad or afail else 0)


if __name__ == '__main__':
    main()
