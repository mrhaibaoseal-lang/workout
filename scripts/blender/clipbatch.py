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
"""
import argparse, ast, glob, hashlib, json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CACHE = os.path.join(ROOT, 'out', 'clipcache')
DEFAULT_BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
COMMON = ['hero_proto.py', 'moves3d.py', 'gear_util.py', 'clipcheck.py']


def sha(paths):
    h = hashlib.sha256()
    for p in sorted(paths):
        h.update(os.path.relpath(p, HERE).replace('\\', '/').encode())
        h.update(open(p, 'rb').read())
    return h.hexdigest()[:16]


def collect_moves():
    moves = {}
    for f in sorted(glob.glob(os.path.join(HERE, 'moves', '*.py'))):
        for n in ast.parse(open(f, encoding='utf-8').read()).body:
            if isinstance(n, ast.Assign) and any(getattr(t, 'id', '') == 'MOVE_META' for t in n.targets):
                for k in ast.literal_eval(n.value):
                    moves[k] = f
    return moves


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--moves'); ap.add_argument('--series')
    ap.add_argument('--force', action='store_true', help='忽略快取全部重跑')
    ap.add_argument('--dry', action='store_true', help='只列出要跑哪些組')
    ap.add_argument('-j', type=int, default=2, help='同時跑幾個 Blender')
    ap.add_argument('--blender', default=os.environ.get('BLENDER', DEFAULT_BLENDER))
    a = ap.parse_args()

    moves = collect_moves(); series = collect_series()
    if a.moves:
        want = a.moves.split(','); bad = [m for m in want if m not in moves]
        if bad: sys.exit(f'沒有這些動作：{bad}；可用：{sorted(moves)}')
        moves = {m: moves[m] for m in want}
    if a.series:
        want = a.series.split(','); bad = [s for s in want if s not in series]
        if bad: sys.exit(f'沒有這些系列：{bad}；可用：{series}')
        series = want

    common = [os.path.join(HERE, f) for f in COMMON] + glob.glob(os.path.join(HERE, 'moves', 'props_*.py'))
    todo, cached = [], []
    for m, mf in sorted(moves.items()):
        for s in series:
            files = common + [mf] + ([os.path.join(HERE, f'gear_{s}.py')] if s != 'basic' else [])
            stamp = sha(set(files)); d = os.path.join(CACHE, f'{m}__{s}')
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

    # 總表：合併快取裡所有組（包括這次沒選到的），只列需要人看的
    allres = []
    for sp in glob.glob(os.path.join(CACHE, '*', 'stamp.json')):
        allres.append(json.load(open(sp, encoding='utf-8')))
    os.makedirs(CACHE, exist_ok=True)
    json.dump(sorted(allres, key=lambda r: (r['move'], r['series'])),
              open(os.path.join(CACHE, 'summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    bad = [r for r in results if not r.get('ok')]
    hot = sorted((r for r in results if r.get('ok') and (r['clip'] or r['sink'])), key=lambda r: -r['clip'])
    print(f'\n這次範圍：乾淨 {len(results) - len(bad) - len(hot)}、要看 {len(hot)}、失敗 {len(bad)}')
    for r in hot:
        print(f'  {r["move"]:14} × {r["series"]:6}  穿模 {r["clip"]:5}  沉地 {r["sink"]:4}  最嚴重格 {r["worst"]}')
    for r in bad:
        print(f'  失敗 {r["move"]} × {r["series"]}：看 out/clipcache/{r["move"]}__{r["series"]}/log.txt')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
