"""審查總覽圖（BLENDER_BRIEF §8、§9-1）：每個動作一張 4 鏡頭 × 4 時間點的圖，加一張整批縮圖。
python scripts/blender/review_sheet.py standing_dumbbell          # 一個批次檔（moves/<名稱>.py 的全部動作）
python scripts/blender/review_sheet.py --moves squat,press        # 指定動作
選項：--name 批次名稱（輸出資料夾名，指定動作時預設 custom）  --fresh 不用 clipcache 的 hero.blend、重建
      --cell 每格像素（預設 400）  -j 同時跑幾個 Blender  --blender 路徑
輸出：out/review/<批次>/<動作>.png（4×4）、out/review/<批次>/_overview.png（整批縮圖）、<動作>/cells/（原始小圖）。不進 git。
用基本款（不穿系列裝備）、草稿品質。hero.blend：clipcache 裡基本款那組的指紋是最新的就直接用，否則重建。
格子上標：動作名｜鏡頭｜時間點｜第幾格。每張圖上方標題含「關鍵角度」和 MOVE_META angles 的判定（PASS／FAIL／未設定）。
時間點怎麼選見 review_render.py 的檔頭。
"""
import argparse, json, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import clipbatch as cb

ROOT = cb.ROOT
BG, FG, DIM = [0.09, 0.10, 0.14], [1, 1, 1], [0.62, 0.68, 0.78]
RED, GREEN = [1, 0.45, 0.4], [0.5, 0.9, 0.55]


def blender_run(blender, args, log):
    with open(log, 'w', encoding='utf-8', errors='replace') as f:
        return subprocess.run([blender] + args, stdout=f, stderr=subprocess.STDOUT).returncode


def make_hero(move, mfile, d, blender, fresh):
    cd = os.path.join(cb.CACHE, f'{move}__basic'); sp = os.path.join(cd, 'stamp.json')
    if not fresh and os.path.exists(sp) and os.path.exists(os.path.join(cd, 'hero.blend')) \
            and json.load(open(sp, encoding='utf-8')).get('stamp') == cb.group_stamp(move, mfile, 'basic'):
        return os.path.join(cd, 'hero.blend'), '沿用 clipcache'
    os.makedirs(d, exist_ok=True)
    env = dict(os.environ, GEAR='basic', MOVE=move, QUICK='1', NORENDER='1'); env.pop('EXPORT', None)
    with open(os.path.join(d, 'hero_log.txt'), 'w', encoding='utf-8', errors='replace') as f:
        r = subprocess.run([blender, '-b', '-P', os.path.join(HERE, 'hero_proto.py'), '--', d, '0'], env=env, stdout=f, stderr=subprocess.STDOUT)
    return (os.path.join(d, 'hero.blend') if r.returncode == 0 else None), '重建'


def render_move(move, mfile, d, blender, fresh, cell):
    os.makedirs(d, exist_ok=True)
    hero, how = make_hero(move, mfile, d, blender, fresh)
    if not hero: return move, None, 'hero_proto 失敗（看 hero_log.txt）'
    rc = blender_run(blender, ['-b', hero, '-P', os.path.join(HERE, 'review_render.py'), '--', d, str(cell)], os.path.join(d, 'render_log.txt'))
    if rc or not os.path.exists(os.path.join(d, 'meta.json')): return move, None, 'review_render 失敗（看 render_log.txt）'
    return move, json.load(open(os.path.join(d, 'meta.json'), encoding='utf-8')), how


def compose(blender, spec, tag):
    sp = spec['out'] + '.json'
    json.dump(spec, open(sp, 'w', encoding='utf-8'), ensure_ascii=False)
    rc = blender_run(blender, ['-b', '-P', os.path.join(HERE, 'compose.py'), '--', sp], spec['out'] + '.log')
    if rc or not os.path.exists(spec['out']): print(f'  拼圖失敗 {tag}（看 {spec["out"]}.log）')
    else: os.remove(sp); os.remove(spec['out'] + '.log')


def sheet(move, meta, verdict, d, outdir, blender, cell, title):
    HEAD = 110
    key = meta['key']; q = meta['q']; fr = meta['frames']
    if key:
        v = q[key]
        kline = f'關鍵角度 {key}：起始 {v[0]:.0f}° → 最深 {v[fr[2] - fr[0]]:.0f}°（第 {fr[2]} 格）'
    else: kline = '角度變化 < 5°，「最深」用動作中點'
    status = verdict['status']
    aline = f'[angles] {status}' + ('：' + '；'.join(verdict['fails']) if verdict['fails'] else '')
    items = [{'type': 'text', 'text': f'{move}　{title}', 'x': 12, 'y': 8, 'size': 34, 'color': FG},
             {'type': 'text', 'text': kline, 'x': 12, 'y': 50, 'size': 22, 'color': DIM},
             {'type': 'text', 'text': aline, 'x': 12, 'y': 78, 'size': 22,
              'color': RED if status == 'FAIL' else GREEN if status == 'PASS' else DIM}]
    for r, cam in enumerate(meta['cams']):
        for c, (f, nm) in enumerate(zip(fr, meta['names'])):
            x, y = c * cell, HEAD + r * cell
            items.append({'type': 'image', 'path': os.path.join(d, 'cells', f'{cam}_{f}.png'), 'x': x, 'y': y, 'w': cell})
            items.append({'type': 'text', 'text': f'{move}｜{cam}｜{nm}｜{f}', 'x': x + 6, 'y': y + 4, 'size': 19, 'color': [1, 0.92, 0.6]})
    out = os.path.join(outdir, f'{move}.png')
    compose(blender, {'out': out, 'w': cell * 4, 'h': cell * 4 + HEAD, 'bg': BG, 'items': items}, move)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('batch', nargs='?', help='批次檔名稱（moves/<名稱>.py，不含 .py）')
    ap.add_argument('--moves'); ap.add_argument('--name')
    ap.add_argument('--fresh', action='store_true'); ap.add_argument('--cell', type=int, default=400)
    ap.add_argument('-j', type=int, default=2); ap.add_argument('--blender', default=os.environ.get('BLENDER', cb.DEFAULT_BLENDER))
    a = ap.parse_args()
    meta = cb.collect_meta()
    if a.moves:
        names = a.moves.split(','); bad = [m for m in names if m not in meta]
        if bad: sys.exit(f'沒有這些動作：{bad}；可用：{sorted(meta)}')
        batch = a.name or 'custom'
    elif a.batch:
        names = [m for m, (f, _) in meta.items() if os.path.basename(f)[:-3] == a.batch]
        if not names: sys.exit(f'沒有這個批次檔：{a.batch}；可用：{sorted({os.path.basename(f)[:-3] for f, _ in meta.values()})}')
        batch = a.name or a.batch
    else: sys.exit('要指定批次檔名稱或 --moves')
    if not os.path.exists(a.blender): sys.exit(f'找不到 Blender：{a.blender}')
    outdir = os.path.join(ROOT, 'out', 'review', batch); os.makedirs(outdir, exist_ok=True)
    print(f'審查總覽圖：{batch}（{len(names)} 個動作）→ {outdir}')

    with ThreadPoolExecutor(a.j) as ex:
        res = list(ex.map(lambda m: render_move(m, meta[m][0], os.path.join(outdir, m), a.blender, a.fresh, a.cell), names))
    sheets = []
    for (m, mt, how) in res:
        if not mt: print(f'  失敗 {m}：{how}'); continue
        st, fails, _ = cb.judge({'q': mt['q']}, meta[m][1].get('angles'))
        v = {'status': st, 'fails': fails}
        out = sheet(m, mt, v, os.path.join(outdir, m), outdir, a.blender, a.cell, batch)
        sheets.append((m, out, v)); print(f'  {m}：{how}；格 {mt["frames"]}（關鍵角度 {mt["key"]}）；[angles] {st}' + (' ' + '；'.join(fails) if fails else ''))

    # 整批縮圖：每張動作圖縮到 TW 寬，3 欄
    if sheets:
        TW, COLS, LH = 560, 3, 34
        th = round(TW * (a.cell * 4 + 110) / (a.cell * 4)); items = []
        for i, (m, out, v) in enumerate(sheets):
            x, y = (i % COLS) * TW, (i // COLS) * (th + LH)
            items.append({'type': 'text', 'text': f'{m}　[angles] {v["status"]}', 'x': x + 8, 'y': y + 6, 'size': 22,
                          'color': RED if v['status'] == 'FAIL' else FG})
            items.append({'type': 'image', 'path': out, 'x': x, 'y': y + LH, 'w': TW})
        rows = (len(sheets) + COLS - 1) // COLS
        compose(a.blender, {'out': os.path.join(outdir, '_overview.png'), 'w': TW * min(COLS, len(sheets)), 'h': rows * (th + LH),
                            'bg': BG, 'items': items}, 'overview')
        print(f'\n總覽：{os.path.join(outdir, "_overview.png")}')
    sys.exit(0 if len(sheets) == len(names) else 1)


if __name__ == '__main__':
    main()
