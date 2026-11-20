// 牌位獎章的形狀資料產生器。
// node scripts/art/badges.js → 產生 Workout/Rank/RankBadgeArt.swift 與預覽 HTML（第二個參數是預覽輸出路徑）。
// 每一階外框形狀都不同，不只是換顏色。座標系 120×120。
const fs = require('fs');
const path = require('path');

const f = (n) => (Math.round(n * 10) / 10).toString();
const P = (pts) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join(' L') + ' Z';
const circle = (cx, cy, r) => {
  const k = 0.5523 * r;
  return `M${f(cx)} ${f(cy - r)} C${f(cx + k)} ${f(cy - r)} ${f(cx + r)} ${f(cy - k)} ${f(cx + r)} ${f(cy)}` +
    ` C${f(cx + r)} ${f(cy + k)} ${f(cx + k)} ${f(cy + r)} ${f(cx)} ${f(cy + r)}` +
    ` C${f(cx - k)} ${f(cy + r)} ${f(cx - r)} ${f(cy + k)} ${f(cx - r)} ${f(cy)}` +
    ` C${f(cx - r)} ${f(cy - k)} ${f(cx - k)} ${f(cy - r)} ${f(cx)} ${f(cy - r)} Z`;
};
const ellipseRot = (cx, cy, rx, ry, deg) => {
  const a = deg * Math.PI / 180, n = 12, pts = [];
  for (let i = 0; i < n; i++) {
    const t = i / n * 2 * Math.PI, x = rx * Math.cos(t), y = ry * Math.sin(t);
    pts.push([cx + x * Math.cos(a) - y * Math.sin(a), cy + x * Math.sin(a) + y * Math.cos(a)]);
  }
  // 平滑：用二次曲線經過中點
  let d = '';
  for (let i = 0; i < n; i++) {
    const p0 = pts[i], p1 = pts[(i + 1) % n];
    const m = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2];
    if (i === 0) d += `M${f(m[0])} ${f(m[1])}`;
    const p2 = pts[(i + 2) % n];
    const m2 = [(p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2];
    d += ` Q${f(p1[0])} ${f(p1[1])} ${f(m2[0])} ${f(m2[1])}`;
  }
  return d + ' Z';
};
const regular = (cx, cy, r, n, rot = -90) => {
  const pts = [];
  for (let i = 0; i < n; i++) {
    const a = (rot + i * 360 / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return pts;
};
const star = (cx, cy, n, ro, ri, rot = -90) => {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 ? ri : ro, a = (rot + i * 180 / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return pts;
};
const mirrorPts = (pts) => pts.map(([x, y]) => [120 - x, y]);
const mirrorD = (d) => d.replace(/([MLQC])([^MLQCZ]*)/g, (m, c, args) => {
  const nums = args.trim().split(/[\s,]+/).filter(Boolean).map(Number);
  const out = [];
  for (let i = 0; i < nums.length; i += 2) out.push(`${f(120 - nums[i])} ${f(nums[i + 1])}`);
  return c + out.join(' ') + ' ';
}).trim();

// 顏色
const PAL = [
  ['鐵牌', '#C3C8CF', '#6A707A', '#2A2E35'],
  ['銅牌', '#F6BE8A', '#B0652F', '#4A2410'],
  ['銀牌', '#FFFFFF', '#A9B6C8', '#3E4756'],
  ['金牌', '#FFEB99', '#E2A521', '#6A4205'],
  ['白金', '#C8FFF4', '#34C2B0', '#0B4D4A'],
  ['鑽石', '#DDE8FF', '#5B7BF0', '#1C2370'],
  ['大師', '#F0D4FF', '#A050E8', '#3A0F63'],
  ['王者', '#FFE0B0', '#F0523C', '#6A0A1A'],
];
const GOLD = ['#FFF3B0', '#F2B630', '#7A4A00'];

// 圖層：{d, fill: ['solid',hex,alpha] | ['lin',[hex...]] | ['rad',[[hex,a],[hex,a]]], stroke, sw}
function L(d, fill, stroke = null, sw = 0) { return { d, fill, stroke, sw }; }

// ---------- 動畫用的圖層標籤 ----------
// part：這一層是獎章的哪個部位，App 和預覽依 MOTION 表讓同一個部位做同一種動作。
// px, py：旋轉／縮放的支點；i：同部位的第幾片（錯開節奏用）；m：左右鏡像的那一份（擺動方向相反）；
// clip：獎章輪廓，反光掃過時只畫在這幾層裡面。
const PART = { body: 0, aura: 1, rays: 2, wing: 3, cog: 4, leaf: 5, tail: 6, spike: 7, crown: 8, flame: 9,
  arm: 10, power: 11, sparkle: 12, gem: 13, star: 14, plate: 15, sword: 16, shard: 17 };
const tag = (layers, part, px = 60, py = 58, i = 0) => layers.map((l) => ({ ...l, part: PART[part], px, py, i }));
const asClip = (l) => ({ ...l, clip: true });
const shiftY = (layers, dy) => layers.map((l) => ({ ...l, d: l.d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _, y) => `${x} ${f(Number(y) + dy)}`), py: (l.py ?? 58) + dy }));
const solid = (h, a = 1) => ['solid', h, a];
const lin = (...hs) => ['lin', hs];
const rad = (h, a0, a1 = 0) => ['rad', [[h, a0], [h, a1]]];

// 中央圖案（0.8.0 起）：肌肉手臂，牌位越高肌肉越大。
// 舊的器材圖示（啞鈴、壺鈴、槓鈴…）保留在 emblem() 裡，BADGE_EMBLEM=tool 可產生舊版預覽對照。
const MUSCLE = process.env.BADGE_EMBLEM !== 'tool';
const EMBLEM_TIER = { dumbbell: 0, kettlebell: 1, barbell: 2, star: 3, hexgem: 4, brilliant: 5, eye: 6, trophy: 7 };

// 彎手臂秀二頭肌，拳頭正面朝前：t = 0（鐵，細瘦平直的手臂）→ 7（王者，巨大二頭肌、粗前臂）。
// 手臂整體大小、上臂粗細、二頭肌隆起、前臂外側都跟著 t 變；拳頭只略微變大，讓肌肉差距更明顯。
function muscleArm(t, lt, md, dk) {
  const m = t / 7;
  const W = '#FFFFFF';
  const k = 0.64 + m * 0.24;                 // 手臂縮放：鐵 0.64 → 王者 0.88
  const pt = (x, y) => `${f(61.5 + x * k)} ${f(65 + y * k)}`;
  const o = [];
  const top = 2 - m * 4;      // 肩膀處上臂上緣
  const bul = m * 11.5;       // 二頭肌隆起（鐵幾乎沒有）
  const fore = 10 + m * 9;    // 前臂外側肌肉
  const tri = 7 + m * 6;      // 三頭肌下緣
  const d = `M${pt(-17, top)}` +
    ` Q${pt(-8, top - 4 - bul * 1.5)} ${pt(1, -4)}` +                   // 二頭肌上緣
    ` Q${pt(1.6, -9)} ${pt(2.5, -13)}` +                                // 前臂內側到手腕
    ` L${pt(8.5, -13)}` +                                               // 手腕（被拳頭蓋住）
    ` Q${pt(fore, -5)} ${pt(12 + m * 2, 4)}` +                          // 前臂外側
    ` Q${pt(12.5 + m * 2, tri + 1)} ${pt(6, tri + 1)}` +                // 手肘
    ` Q${pt(-5, tri + 2 + m * 3)} ${pt(-17, tri)} Z`;                   // 三頭肌下緣
  o.push(L(d, lin(W, lt, md), dk, 1.6));
  const peak = 0.75 * top - 3 - 0.75 * bul;   // 二頭肌最高點（曲線中點）
  o.push(L(`M${pt(1, -4)} Q${pt(3.5, -0.5)} ${pt(7, 1.5)}`, solid(W, 0), dk, 1.1));     // 手肘內側摺線
  if (t >= 2) o.push(L(ellipseRot(61.5 - 8 * k, 65 + (peak + 3 + m * 3.2) * k, (3.5 + m * 3.5) * k, (1.2 + m * 1.5) * k, -10), solid(W, 0.8)));   // 光澤
  if (t >= 4) o.push(L(`M${pt(-15, top + 5)} Q${pt(-9, top + 1.5)} ${pt(-4, top + 5)} Q${pt(1, top + 7.5)} ${pt(5, 3)}`, solid(W, 0), dk, 0.9));   // 青筋
  if (t >= 6) for (const dx of [-12, -6]) o.push(L(`M${pt(dx, peak + 5.5)} Q${pt(dx + 1.6, peak + 8)} ${pt(dx + 0.6, top + 4)}`, solid(W, 0), dk, 0.8)); // 肌肉線條

  // 拳頭：正面握拳（指節朝前），接在手腕上，隨手臂略微變大。手掌塊在後，4 根寬短的圓頭手指，粗拇指橫壓在手指下緣。
  const fs = 0.47 + m * 0.12;   // 拳頭跟手臂成比例：細手臂配小拳頭（鐵 0.47 → 王者 0.59）
  const wx = 61.5 + 5.5 * k, wy = 65 - 13 * k;
  const pf = (x, y) => `${f(wx + (x - 5.5) * fs)} ${f(wy + (y + 13) * fs)}`;
  const skin = lin(W, lt);
  const rr = (x0, y0, x1, y1, r) => `M${pf(x0 + r, y0)} L${pf(x1 - r, y0)} Q${pf(x1, y0)} ${pf(x1, y0 + r)} L${pf(x1, y1 - r)}` +
    ` Q${pf(x1, y1)} ${pf(x1 - r, y1)} L${pf(x0 + r, y1)} Q${pf(x0, y1)} ${pf(x0, y1 - r)} L${pf(x0, y0 + r)} Q${pf(x0, y0)} ${pf(x0 + r, y0)} Z`;
  o.push(L(`M${pf(1.5, -12.5)} Q${pf(-4, -14.5)} ${pf(-4.2, -19.5)} L${pf(-4.2, -23)} L${pf(14.4, -23)} L${pf(14.4, -18.5)}` +
    ` Q${pf(14.2, -13.8)} ${pf(10, -12.5)} Z`, skin, dk, 1.3));                                                                // 手掌
  [[-4.2, 0.5, -28.2], [0.5, 5.2, -29.6], [5.2, 9.9, -29.2], [9.9, 14.4, -27.6]].forEach(([x0, x1, y0]) =>
    o.push(L(rr(x0, y0, x1, -21, 2.2), skin, dk, 1.2)));                                                                     // 手指
  // 拇指：從食指那側橫壓過來，指尖只到中指（第二根）上，不越過無名指
  o.push(L(`M${pf(-4.6, -16.6)} Q${pf(-4.8, -21.8)} ${pf(-0.4, -22)} L${pf(4.2, -22.3)} Q${pf(7.2, -22.2)} ${pf(7, -19.7)}` +
    ` Q${pf(6.7, -17.3)} ${pf(4.2, -17.1)} L${pf(1.4, -16.4)} Q${pf(-1.4, -14.2)} ${pf(-4.6, -16.6)} Z`, skin, dk, 1.2));
  if (t >= 3) { // 力量線，在拳頭右側
    const n = t >= 7 ? 3 : t >= 5 ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const a = (-30 + i * 32) * Math.PI / 180, c = [5, -21];
      o.push({ ...L(`M${pf(c[0] + 13 * Math.cos(a), c[1] + 13 * Math.sin(a))} L${pf(c[0] + 18.5 * Math.cos(a), c[1] + 18.5 * Math.sin(a))}`, solid(W, 0), W, 1.5), power: true, i });
    }
  }
  // 手臂整組以手肘附近為支點「用力」；力量線另外閃
  return o.map((l) => ({ ...l, part: l.power ? PART.power : PART.arm, px: 61.5, py: 65 + 2 * k, i: l.i ?? 0 }));
}

// 中央圖案
function emblem(kind, lt, md, dk) {
  if (MUSCLE && kind in EMBLEM_TIER) return muscleArm(EMBLEM_TIER[kind], lt, md, dk);
  const o = [];
  const W = '#FFFFFF';
  switch (kind) {
    case 'dumbbell': {
      const r = (x, y, w, h) => P([[x, y], [x + w, y], [x + w, y + h], [x, y + h]]);
      o.push(L(r(49, 57, 22, 4), solid(lt), dk, 1.2));
      for (const [x, h] of [[44, 18], [71, 18], [40, 12], [76, 12]]) o.push(L(r(x, 59 - h / 2, x < 50 || x > 70 ? 5 : 5, h), solid(lt), dk, 1.2));
      break;
    }
    case 'kettlebell': {
      o.push(L(circle(60, 64, 11), lin(lt, md), dk, 1.5));
      o.push(L('M51 58 Q50 44 60 44 Q70 44 69 58 L65 58 Q65 49 60 49 Q55 49 55 58 Z', solid(lt), dk, 1.5));
      o.push(L(ellipseRot(56, 61, 2.5, 4, 30), solid(W, 0.7)));
      break;
    }
    case 'barbell': {
      o.push(L(P([[34, 57.5], [86, 57.5], [86, 60.5], [34, 60.5]]), solid(lt), dk, 1));
      for (const x of [41, 74]) o.push(L(P([[x, 46], [x + 5, 46], [x + 5, 72], [x, 72]]), lin(lt, md), dk, 1.2));
      for (const x of [47, 70]) o.push(L(P([[x, 50], [x + 3, 50], [x + 3, 68], [x, 68]]), solid(lt), dk, 1));
      break;
    }
    case 'star':
      o.push(L(P(star(60, 59, 5, 15, 6.5)), lin('#FFFFFF', lt, md), dk, 1.5));
      break;
    case 'hexgem': {
      const h = regular(60, 59, 14, 6);
      o.push(L(P(h), solid(md), null));
      for (let i = 0; i < 6; i++) {
        const sh = [W, lt, md, dk, md, lt][i];
        o.push(L(P([[60, 59], h[i], h[(i + 1) % 6]]), solid(sh, i === 0 ? 0.9 : 1)));
      }
      o.push(L(P(regular(60, 59, 6, 6)), solid(W, 0.55)));
      o.push(L(P(h), solid(W, 0), W, 1.2));
      break;
    }
    case 'brilliant': {
      const top = [[48, 54], [53, 47], [67, 47], [72, 54]], bot = [60, 74];
      o.push(L(P([...top, bot]), solid(md)));
      o.push(L(P([[53, 47], [67, 47], [64, 54], [56, 54]]), solid(W, 0.95)));
      o.push(L(P([[48, 54], [53, 47], [56, 54]]), solid(lt)));
      o.push(L(P([[72, 54], [67, 47], [64, 54]]), solid(md)));
      o.push(L(P([[48, 54], [56, 54], bot]), solid(lt)));
      o.push(L(P([[56, 54], [64, 54], bot]), solid(md)));
      o.push(L(P([[64, 54], [72, 54], bot]), solid(dk)));
      o.push(L(P([...top, bot]), solid(W, 0), W, 1.2));
      break;
    }
    case 'eye': {
      o.push(L(P(star(60, 59, 4, 17, 5, -90)), lin('#FFFFFF', lt), dk, 1.2));
      o.push(L(circle(60, 59, 5), solid(md), W, 1.2));
      break;
    }
    case 'trophy': {
      o.push(L('M49 46 L71 46 L70 54 Q68 64 60 65 Q52 64 50 54 Z', lin(GOLD[0], GOLD[1]), GOLD[2], 1.5));
      o.push(L('M49 48 Q42 48 43 54 Q44 59 51 59 L51 56 Q47 56 46.5 54 Q46 51 49 51 Z', solid(GOLD[1]), GOLD[2], 1));
      o.push(L(mirrorD('M49 48 Q42 48 43 54 Q44 59 51 59 L51 56 Q47 56 46.5 54 Q46 51 49 51 Z'), solid(GOLD[1]), GOLD[2], 1));
      o.push(L(P([[58, 65], [62, 65], [63, 69], [57, 69]]), solid(GOLD[1]), GOLD[2], 1));
      o.push(L(P([[52, 69], [68, 69], [69, 73], [51, 73]]), solid(GOLD[1]), GOLD[2], 1.2));
      o.push(L(P(star(60, 54, 5, 5, 2.2)), solid('#FFFFFF')));
      break;
    }
  }
  return o;
}

function feathers(n, x0, y0, spanX, spanY, lt, md, dk, sw = 1.6) {
  // 從 (x0,y0) 往右上展開的一片片羽毛，最外層最長。回傳右側；左側另外鏡像。
  const out = [];
  for (let i = n - 1; i >= 0; i--) {
    const t = i / Math.max(1, n - 1);
    const ang = (-38 + t * 70) * Math.PI / 180;
    const len = spanX * (1 - t * 0.45);
    const bx = x0, by = y0 + t * spanY * 0.35;
    const tx = bx + len * Math.cos(ang), ty = by + len * Math.sin(ang);
    const nx = -Math.sin(ang), ny = Math.cos(ang);
    const wdt = 5 + (1 - t) * 3;
    const d = `M${f(bx)} ${f(by - wdt * 0.6)} Q${f((bx + tx) / 2 - nx * wdt)} ${f((by + ty) / 2 - ny * wdt)} ${f(tx)} ${f(ty)}` +
      ` Q${f((bx + tx) / 2 + nx * wdt * 0.9)} ${f((by + ty) / 2 + ny * wdt * 0.9)} ${f(bx)} ${f(by + wdt)} Z`;
    out.push({ ...L(d, solid(i % 2 ? md : lt), dk, sw), part: PART.wing, px: bx, py: by, i });
  }
  return out;
}
// 左右對稱：鏡像的那一份 m = true，支點也鏡像
const both = (layers) => [...layers, ...layers.map((l) => ({ ...l, d: mirrorD(l.d), m: !l.m, px: l.px === undefined ? undefined : 120 - l.px }))];

// lv：小段華麗程度，0 = III、1 = II、2 = I（大師、王者固定 2）。
// 差異刻意拉大：III 是樸素的核心徽章（整體縮小），II 加上該階的招牌配件，I 配件加大加多、背後有光暈和星光。
const scaleD = (d, k, cx = 60, cy = 58) => d.replace(/([MLQC])([^MLQCZ]*)/g, (m, c, args) => {
  const nums = args.trim().split(/[\s,]+/).filter(Boolean).map(Number);
  const out = [];
  for (let i = 0; i < nums.length; i += 2) out.push(`${f(cx + (nums[i] - cx) * k)} ${f(cy + (nums[i + 1] - cy) * k)}`);
  return c + out.join(' ') + ' ';
}).trim();
const sparkles = (pts) => pts.map(([x, y, r], i) => ({ ...L(P(star(x, y, 4, r, r * 0.3)), solid('#FFFFFF')), part: PART.sparkle, px: x, py: y, i }));

function tierLayers(ti, lv = 2) {
  const core = tierCore(ti, lv);
  if (ti >= 6) return core;
  const k = [0.86, 0.94, 1][lv];
  const o = [];
  if (lv >= 2) o.push(...tag([L(circle(60, 58, 58), rad(PAL[ti][2], 0.75))], 'aura'));
  o.push(...core.map((l) => ({ ...l, d: scaleD(l.d, k),
    px: l.px === undefined ? undefined : 60 + (l.px - 60) * k, py: l.py === undefined ? undefined : 58 + (l.py - 58) * k })));
  if (lv >= 2) o.push(...sparkles(ti === 2 ? [[10, 50, 5.5], [110, 50, 5.5], [14, 76, 4], [106, 76, 4]] : [[12, 20, 6], [108, 20, 6], [8, 84, 4.5], [112, 84, 4.5]]));
  return o;
}

function tierCore(ti, lv) {
  const [, lt, md, dk] = PAL[ti];
  const o = [];
  const metal = lin(lt, md, dk);
  const W = '#FFFFFF';
  switch (ti) {
    case 0: { // 鐵：八角鐵板。III 素面；II 加鉚釘＋兩側鐵夾板；I 夾板加長成雙層＋頂端三根鐵刺
      if (lv >= 2) {
        [[60, 20, 6], [44, 13, 5], [76, 13, 5]].forEach(([x, h, w], i) => o.push(...tag([L(P([[x - w, 27], [x, 27 - h], [x + w, 27]]), metal, dk, 1.4)], 'spike', x, 27, i)));
        o.push(...both(tag([L(P([[92, 40], [112, 44], [112, 72], [92, 76]]), metal, dk, 1.5),
          L(circle(106, 50, 2), solid(lt), dk, 1), L(circle(106, 66, 2), solid(lt), dk, 1)], 'plate', 92, 58, 1)));
      }
      if (lv >= 1) {
        o.push(...both(tag([L(P([[86, 46], [100, 49], [100, 67], [86, 70]]), metal, dk, 1.5),
          L(circle(95, 58, 2.2), solid(lt), dk, 1)], 'plate', 86, 58, 0)));
      }
      o.push(asClip(L(P(regular(60, 58, 36, 8, -67.5)), solid(dk))));
      o.push(L(P(regular(60, 58, 32, 8, -67.5)), metal, dk, 1.5));
      o.push(L(P(regular(60, 58, 24, 8, -67.5)), solid(dk, 0.35)));
      if (lv >= 1) for (const [x, y] of regular(60, 58, 28, 8, -67.5)) o.push(L(circle(x, y, 2.4), solid(lt), dk, 1));
      o.push(L('M40 40 L47 45', solid(W, 0), W, 1));
      o.push(...emblem('dumbbell', lt, md, dk));
      break;
    }
    case 1: { // 銅：齒輪圓章。III 只有齒輪；II 加緞帶尾＋半圈月桂；I 整圈月桂＋雙層緞帶尾＋頂端星
      const tail = P([[44, 80], [36, 108], [44, 103], [50, 110], [54, 82]]);
      if (lv >= 2) o.push(...both(tag([L(P([[38, 76], [22, 100], [32, 98], [34, 108], [46, 80]]), solid(dk), lt, 1.2)], 'tail', 42, 78, 1)));
      if (lv >= 1) o.push(...both(tag([L(tail, solid(md), dk, 1.5)], 'tail', 49, 81, 0)));
      const leaves = [];
      const n = [0, 4, 7][lv];
      for (let i = 0; i < n; i++) {
        const deg = 200 - i * 22;
        const a = deg * Math.PI / 180;
        const cx = 60 + 39 * Math.cos(a), cy = 60 - 39 * Math.sin(a);
        leaves.push(...tag([L(ellipseRot(cx, cy, 3.6, 8, -(deg - 90) + 35), lin('#CFE8A0', '#5E8A2E'), '#2E4A12', 1.2)], 'leaf', cx, cy, i));
      }
      o.push(...both(leaves));
      if (lv >= 2) o.push(...tag([L(P(star(60, 12, 5, 11, 4.6)), lin('#FFFFFF', lt, md), dk, 1.4)], 'star', 60, 12));
      const cog = [];
      for (let i = 0; i < 32; i++) {
        const r = i % 4 < 2 ? 33 : 29, a = (i / 32 * 360 + 5.6) * Math.PI / 180;
        cog.push([60 + r * Math.cos(a), 58 + r * Math.sin(a)]);
      }
      o.push(asClip(tag([L(P(cog), metal, dk, 1.8)], 'cog')[0]));
      o.push(L(circle(60, 58, 24), lin(md, dk), lt, 1.5));
      if (lv >= 2) o.push(L(circle(60, 58, 20.5), solid(W, 0), lt, 1));
      o.push(...emblem('kettlebell', lt, md, dk));
      break;
    }
    case 2: { // 銀：盾牌。III 只有盾；II 交叉雙劍；I 雙劍＋盾頂矛尖＋金邊盾與金鉚釘
      const sword = (flip) => {
        const s2 = [L(P([[6, 10], [10, 4], [17, 7], [86, 82], [80, 88]]), lin(W, md), dk, 1.4),
          L(P([[11, 7], [83, 85]]), solid(W, 0), dk, 1),
          L(P([[74, 88], [88, 74], [92, 78], [78, 92]]), solid(GOLD[1]), GOLD[2], 1.2),
          L(P([[84, 86], [88, 82], [100, 96], [96, 100]]), solid('#5A3B22'), GOLD[2], 1.2),
          L(circle(99, 99, 3.5), solid(GOLD[1]), GOLD[2], 1.2)];
        const t2 = tag(s2, 'sword', 60, 60);
        return flip ? t2.map((l) => ({ ...l, d: mirrorD(l.d), m: true })) : t2;
      };
      if (lv >= 1) o.push(...sword(false), ...sword(true));
      if (lv >= 2) {
        o.push(...tag([L(P([[60, 0], [67, 13], [63, 12], [60, 21], [57, 12], [53, 13]]), lin(W, md), dk, 1.4)], 'spike', 60, 20));
      }
      const sh = 'M60 18 Q76 26 90 24 L90 58 Q90 84 60 100 Q30 84 30 58 L30 24 Q44 26 60 18 Z';
      o.push(asClip(L(sh, solid(dk))));
      o.push(L('M60 23 Q75 30 86 28.5 L86 58 Q86 81 60 95 Q34 81 34 58 L34 28.5 Q45 30 60 23 Z', metal, null));
      o.push(L('M60 23 L60 95 Q34 81 34 58 L34 28.5 Q45 30 60 23 Z', solid(W, 0.22)));
      o.push(L('M60 30 L80 34 L80 58 Q80 76 60 88 Q40 76 40 58 L40 34 Z', solid(W, 0), W, 1.2));
      if (lv >= 2) {
        o.push(L(sh, solid(W, 0), GOLD[1], 2.4));
        for (const [x, y] of [[32, 27], [88, 27], [32, 56], [88, 56], [60, 97]]) o.push(L(circle(x, y, 2.6), solid(GOLD[0]), GOLD[2], 1));
      }
      o.push(...emblem('barbell', lt, md, dk));
      break;
    }
    case 3: { // 金：圓牌。III 短光芒 8 道；II 12 道＋小翼；I 16 道長光芒＋大翼＋頂端星
      if (lv >= 1) o.push(...both(feathers(lv + 2, 82, 50, [0, 28, 40][lv], [0, 30, 40][lv], lt, md, dk)));
      const rays = [8, 12, 16][lv];
      o.push(...tag([L(P(star(60, 58, rays, [34, 40, 46][lv], 28, -90)), lin(GOLD[0], GOLD[1]), GOLD[2], 1.5)], 'rays'));
      if (lv >= 2) o.push(...tag([L(P(star(60, 6, 5, 9, 3.8)), solid(W), GOLD[2], 1.2)], 'star', 60, 6));
      o.push(asClip(L(circle(60, 58, 27), solid(dk))));
      o.push(L(circle(60, 58, 24), metal, lt, 1.5));
      o.push(L(circle(60, 58, 18), solid(dk, 0.25)));
      o.push(...emblem('star', lt, md, dk));
      break;
    }
    case 4: { // 白金：六角水晶框。III 沒有翼；II 碎晶翼 2 片；I 3 片＋頂端與底部水晶
      const shard = [L(P([[80, 44], [112, 30], [92, 52]]), lin(W, md), dk, 1.5),
        L(P([[84, 56], [116, 56], [88, 66]]), lin(lt, md), dk, 1.5),
        L(P([[82, 68], [104, 84], [80, 76]]), lin(lt, dk), dk, 1.5)];
      o.push(...both(shard.slice(0, [0, 2, 3][lv]).map((l, i) => tag([l], 'shard', 84, 56, i)[0])));
      if (lv >= 2) {
        o.push(...tag([L(P([[60, 0], [67, 20], [60, 25], [53, 20]]), lin(W, md), dk, 1.4)], 'spike', 60, 24, 0));
        o.push(...both(tag([L(P([[72, 14], [76, 26], [70, 26]]), lin(W, md), dk, 1.2)], 'spike', 73, 26, 1)));
      }
      const hx = regular(60, 58, 36, 6);
      o.push(asClip(L(P(hx), solid(dk))));
      const hi = regular(60, 58, 32, 6);
      for (let i = 0; i < 6; i++) {
        const shd = [lt, W, md, dk, md, lt][i];
        o.push(L(P([[60, 58], hi[i], hi[(i + 1) % 6]]), solid(shd)));
      }
      o.push(L(P(regular(60, 58, 21, 6)), lin(md, dk), lt, 1.5));
      o.push(...shiftY(emblem('hexgem', lt, md, dk), -1));
      break;
    }
    case 5: { // 鑽石：大菱形。III 頂端 1 根水晶刺、沒有翼；II 羽翼 4 片＋3 根刺；I 羽翼 6 片加長＋5 根刺
      if (lv >= 1) o.push(...both(feathers([0, 4, 6][lv], 84, 50, [0, 32, 42][lv], [0, 34, 44][lv], lt, md, dk)));
      const spikes = [[[60, 2], [66, 16], [54, 16]], [[38, 10], [48, 22], [41, 24]], [[82, 10], [79, 24], [72, 22]],
        [[24, 26], [36, 32], [31, 37]], [[96, 26], [89, 37], [84, 32]]];
      spikes.slice(0, [1, 3, 5][lv]).forEach((pts, i) => o.push(...tag([L(P(pts), lin(W, md), dk, 1.4)], 'spike', (pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2, i)));
      const dia = [[60, 12], [98, 56], [60, 104], [22, 56]];
      o.push(asClip(L(P(dia), solid(dk))));
      const di = [[60, 18], [92, 56], [60, 98], [28, 56]];
      const c = [60, 56];
      o.push(L(P([di[0], di[1], c]), solid(W)));
      o.push(L(P([di[1], di[2], c]), solid(md)));
      o.push(L(P([di[2], di[3], c]), solid(dk)));
      o.push(L(P([di[3], di[0], c]), solid(lt)));
      o.push(...tag([L(P([[60, 34], [76, 56], [60, 80], [44, 56]]), solid(dk, 0.55), lt, 1.2)], 'gem', 60, 57));
      o.push(...shiftY(emblem('brilliant', lt, md, dk), -3));
      break;
    }
    case 6: { // 大師：星形徽章＋大翼＋皇冠＋紫色光環
      o.push(...tag([L(circle(60, 58, 58), rad(md, 0.85))], 'aura'));
      o.push(...both(feathers(6, 80, 46, 42, 40, lt, md, dk)));
      o.push(asClip(L(P(star(60, 60, 5, 40, 22)), solid(dk))));
      o.push(L(P(star(60, 60, 5, 35, 19)), metal, lt, 1.2));
      o.push(L(circle(60, 61, 16), solid(dk)));
      o.push(...shiftY(emblem('eye', lt, md, dk), 2));
      o.push(...crown('#B07CFF'));
      [[18, 92, 3], [102, 92, 3], [10, 30, 2.4], [110, 30, 2.4]].forEach(([x, y, r], i) => o.push(...tag([L(P(star(x, y, 4, r * 2, r * 0.6)), solid(W))], 'sparkle', x, y, i)));
      break;
    }
    case 7: { // 王者：火焰盾＋巨翼＋寶石皇冠＋光芒
      o.push(...tag([L(circle(60, 58, 60), rad('#FFB347', 0.9))], 'aura'));
      const rays = [];
      for (let i = 0; i < 16; i++) {
        const a = i / 16 * 2 * Math.PI, h = Math.PI / 16 * 0.4, R = 60;
        rays.push(P([[60, 58], [60 + R * Math.cos(a - h), 58 + R * Math.sin(a - h)], [60 + R * Math.cos(a + h), 58 + R * Math.sin(a + h)]]));
      }
      o.push(...tag([L(rays.join(' '), solid('#FFE6A0', 0.45))], 'rays'));
      o.push(...both(feathers(6, 80, 46, 44, 44, lt, md, dk)));
      // 火焰：盾外圈的火舌
      // 每一根火舌分開一層，各自閃動
      for (let i = 0; i < 9; i++) {
        const t = i / 8, x = 30 + t * 60;
        const base = 40 + Math.abs(t - 0.5) * 34;
        const h = 32 - Math.abs(t - 0.5) * 20;
        o.push(...tag([L(`M${f(x - 7)} ${f(base + 8)} Q${f(x - 6)} ${f(base - h * 0.4)} ${f(x + (t < 0.5 ? -3 : 3))} ${f(base - h)} Q${f(x + 6)} ${f(base - h * 0.4)} ${f(x + 7)} ${f(base + 8)} Z`,
          lin('#FFF3A0', '#FF8A1F', '#E0301E'), '#7A1408', 1.2)], 'flame', x, base + 8, i));
      }
      const sh = 'M60 26 Q76 32 90 30 L90 60 Q90 86 60 102 Q30 86 30 60 L30 30 Q44 32 60 26 Z';
      o.push(asClip(L(sh, solid(dk))));
      o.push(L('M60 31 Q75 36 86 34.5 L86 60 Q86 83 60 97 Q34 83 34 60 L34 34.5 Q45 36 60 31 Z', metal));
      o.push(L('M60 31 L60 97 Q34 83 34 60 L34 34.5 Q45 36 60 31 Z', solid(W, 0.2)));
      o.push(L('M60 38 L80 41 L80 60 Q80 78 60 90 Q40 78 40 60 L40 41 Z', solid(GOLD[1], 0), GOLD[0], 1.5));
      o.push(...shiftY(emblem('trophy', lt, md, dk), 4));
      o.push(...crown('#FF3B4E', true));
      break;
    }
  }
  return o;
}

function crown(jewel, big = false) {
  const s = big ? 1.15 : 1;
  const tf = (pts) => pts.map(([x, y]) => [60 + (x - 60) * s, 6 + (y - 6) * s]);
  const o = [];
  const body = tf([[40, 26], [37, 6], [48, 15], [54, 3], [60, 12], [66, 3], [72, 15], [83, 6], [80, 26]]);
  o.push(L(P(body), lin(GOLD[0], GOLD[1]), GOLD[2], 1.8));
  o.push(L(P(tf([[40, 21], [80, 21], [80, 26], [40, 26]])), solid(GOLD[1]), GOLD[2], 1.2));
  for (const [x, y] of [[37, 6], [54, 3], [66, 3], [83, 6]]) {
    const [cx, cy] = tf([[x, y]])[0];
    o.push(L(circle(cx, cy, 2.2), solid('#FFFFFF'), GOLD[2], 1));
  }
  const [jx, jy] = tf([[60, 18]])[0];
  o.push(L(P([[jx, jy - 5], [jx + 4, jy], [jx, jy + 5], [jx - 4, jy]]), solid(jewel), GOLD[2], 1));
  return tag(o, 'crown', 60, 26);
}

function ribbon(ti) {
  const [, lt, md, dk] = PAL[ti];
  return [L(P([[38, 96], [82, 96], [87, 104], [82, 112], [38, 112], [33, 104]]), solid(dk), lt, 1.5)];
}
// 小段：緞帶上的羅馬數字 I / II / III（有上下襯線的字形，畫成路徑，不靠字型）。
// n = 1 → I（最高小段）、3 → III（最低）。
function numerals(n) {
  const top = 98, bot = 110, stem = 3.4, serifW = 6.4, serifH = 2, gap = 8.6;
  const o = [];
  for (let i = 0; i < n; i++) {
    const cx = 60 + (i - (n - 1) / 2) * gap;
    const s = stem / 2, w = serifW / 2;
    o.push(L(P([
      [cx - w, top], [cx + w, top], [cx + w, top + serifH], [cx + s, top + serifH],
      [cx + s, bot - serifH], [cx + w, bot - serifH], [cx + w, bot], [cx - w, bot],
      [cx - w, bot - serifH], [cx - s, bot - serifH], [cx - s, top + serifH], [cx - w, top + serifH],
    ]), solid('#FFFFFF')));
  }
  return o;
}

// ---------- 動畫設定 ----------
// 動作種類（App 的 BadgeMotion 和預覽的 badge-anim.js 用同一套公式）：
// spin 等速轉 a 度/秒｜swing 來回擺 a 度｜pulse 縮放 ±a｜bob 上下 a｜twinkle 星光閃爍｜flex 每 p 秒用力一次（放大 a）
// flicker 火焰抖動（縱向 ±a）｜flash 跟著用力閃｜clash 跟著用力往內砍 a 度｜shake 跟著用力震 a｜glow 透明度 1−a…1｜drift 沿支點往外飄 a
// p：週期秒數；st：同部位每一片錯開幾秒（i × st）
const KIND = { spin: 0, swing: 1, pulse: 2, bob: 3, twinkle: 4, flex: 5, flicker: 6, flash: 7, clash: 8, shake: 9, glow: 10, drift: 11 };
const FLEX = 3.4;   // 手臂用力的週期；力量線、鐵板、雙劍跟著同一個節奏
const op = (part, kind, a = 0, p = 1, st = 0) => ({ part: PART[part], kind: KIND[kind], a, p, st });
const COMMON = [
  op('arm', 'flex', 0.07, FLEX), op('power', 'flex', 0.07, FLEX), op('power', 'flash', 0, FLEX),
  op('sparkle', 'twinkle', 0, 1.8, 0.37), op('aura', 'pulse', 0.05, 2.4), op('aura', 'glow', 0.35, 2.4),
  op('gem', 'pulse', 0.06, 1.6), op('gem', 'glow', 0.4, 1.6), op('star', 'pulse', 0.16, 1.5), op('star', 'swing', 8, 3),
  op('crown', 'bob', -1.6, 2.4),
];
const MOTION = [
  [op('plate', 'shake', 1.3, FLEX), op('spike', 'bob', -1.6, 1.6, 0.25)],                                   // 鐵：用力時鐵板震、鐵刺彈
  [op('cog', 'spin', 14), op('leaf', 'swing', 7, 2.6, 0.45), op('tail', 'swing', 6, 2.2, 0.8)],             // 銅：齒輪轉、月桂擺、緞帶飄
  [op('sword', 'clash', 7, FLEX), op('spike', 'bob', -1.6, 1.8)],                                          // 銀：用力時雙劍交擊
  [op('rays', 'spin', 9), op('rays', 'pulse', 0.04, 2), op('wing', 'swing', 8, 2, 0.22)],                  // 金：光芒轉、翅膀拍
  [op('shard', 'drift', 3, 2.6, 0.9), op('shard', 'swing', 4, 2.6, 0.9), op('spike', 'bob', -2, 2, 0.6)],  // 白金：碎晶浮動
  [op('wing', 'swing', 10, 1.7, 0.25), op('spike', 'bob', -1.8, 1.8, 0.7)],                                // 鑽石：羽翼一片片拍
  [op('wing', 'swing', 9, 2.1, 0.25)],                                                                     // 大師
  [op('rays', 'spin', -12), op('wing', 'swing', 11, 1.8, 0.25), op('flame', 'flicker', 0.16, 1, 1.3)],     // 王者：火舌、巨翼
].map((m) => [...COMMON, ...m]);

// 粒子：mote 往上飄｜orbit 繞圈光點｜glint 閃光十字星｜spark 火花｜fall 往下飄｜spiral 螺旋上升｜ember 火星｜crystal 繞圈小水晶
// n 數量、c/c2 顏色、s 大小、p 週期、r 範圍／半徑、h 高度／橢圓短軸、y 起點
const PK = { mote: 0, orbit: 1, glint: 2, spark: 3, fall: 4, spiral: 5, ember: 6, crystal: 7 };
const pt = (k, n, c, s, p, r, h = 0, y = 0, c2 = c) => ({ k: PK[k], n, c, c2, s, p, r, h, y });
const PARTICLES = [
  [pt('spark', 7, '#FFE2A0', 1.1, 1.7, 40, 0, 88, '#FF7A2A')],
  [pt('mote', 10, '#FFD9A0', 1.4, 3.2, 70, 70, 96)],
  [pt('glint', 4, '#FFFFFF', 5, 2.2, 40), pt('mote', 6, '#E6F0FF', 1.1, 3.6, 70, 70, 96)],
  [pt('orbit', 10, '#FFE48A', 1.8, 6, 50, 16), pt('mote', 10, '#FFE9A0', 1.5, 3, 80, 80, 100), pt('glint', 3, '#FFFBE0', 5, 2.4, 44)],
  [pt('crystal', 6, '#C8FFF4', 3, 7, 54, 18), pt('glint', 4, '#E0FFFA', 5, 2, 44)],
  [pt('glint', 6, '#FFFFFF', 6, 1.8, 46), pt('fall', 12, '#DDE8FF', 1.3, 4, 100, 110), pt('orbit', 8, '#9DB4FF', 1.6, 5, 54, 20)],
  [pt('spiral', 16, '#E3B8FF', 1.6, 3.5, 46, 90, 100), pt('orbit', 12, '#C78BFF', 1.8, 5, 56, 14), pt('glint', 4, '#FFFFFF', 6, 2, 48)],
  [pt('ember', 22, '#FFE08A', 1.8, 2.6, 80, 100, 104, '#FF4A1F'), pt('glint', 4, '#FFF3C0', 6, 2.2, 48)],
];
// 反光掃過：[週期秒數, 強度]
const SHEEN = [[4, 0.35], [3.6, 0.4], [2.8, 0.6], [3, 0.55], [2.6, 0.6], [2.4, 0.7], [3, 0.5], [3, 0.5]];

// ---------- 輸出 ----------
// tiers[階][lv]：有小段的階 3 組（III、II、I），大師、王者 1 組
const tiers = PAL.map((_, i) => (i < 6 ? [0, 1, 2] : [2]).map((lv) => tierLayers(i, lv)));

function svgFill(fill, id) {
  if (fill[0] === 'solid') return { attr: `fill="${fill[1]}" fill-opacity="${fill[2]}"`, defs: '' };
  if (fill[0] === 'lin') {
    const n = fill[1].length;
    const stops = fill[1].map((h, i) => `<stop offset="${n === 1 ? 0 : i / (n - 1)}" stop-color="${h}"/>`).join('');
    return { attr: `fill="url(#${id})"`, defs: `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">${stops}</linearGradient>` };
  }
  const stops = fill[1].map(([h, a], i) => `<stop offset="${i}" stop-color="${h}" stop-opacity="${a}"/>`).join('');
  return { attr: `fill="url(#${id})"`, defs: `<radialGradient id="${id}">${stops}</radialGradient>` };
}
let gid = 0;
function svg(layers, size) {
  let defs = '', body = '';
  for (const l of layers) {
    const id = 'g' + gid++;
    const fl = svgFill(l.fill, id);
    defs += fl.defs;
    body += `<path d="${l.d}" ${fl.attr} ${l.stroke ? `stroke="${l.stroke}" stroke-width="${l.sw}" stroke-linejoin="round" stroke-linecap="round"` : ''}/>`;
  }
  return `<svg width="${size}" height="${size}" viewBox="0 0 120 120"><defs>${defs}</defs>${body}</svg>`;
}
function badge(ti, div, size) {
  const layers = [...tiers[ti][div ? 3 - div : tiers[ti].length - 1]];
  if (div) layers.push(...ribbon(ti), ...numerals(div));
  return svg(layers, size);
}

const preview = process.argv[2];
const DATA = { tiers, ribbons: PAL.map((_, i) => ribbon(i)), numerals: [0, 1, 2, 3].map((n) => (n ? numerals(n) : [])),
  motion: MOTION, particles: PARTICLES, sheen: SHEEN, pal: PAL.map((p) => p.slice(1)), names: PAL.map((p) => p[0]) };
if (preview) {
  // 會動的預覽：和 App 同一份資料、同一套動作公式（scripts/art/badge-anim.js）
  const anim = fs.readFileSync(path.join(__dirname, 'badge-anim.js'), 'utf8');
  let h = '<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>牌位動畫預覽</title>' +
    '<body style="background:#0E1116;color:#ccc;font-family:sans-serif;margin:0;padding:10px">' +
    `<div id=anim></div><script>const BADGE=${JSON.stringify(DATA)};\n${anim}</script>`;
  if (process.env.STATIC !== '0') for (const sz of [150, 58, 44]) {
    h += '<div>';
    PAL.forEach((p, i) => {
      for (const d of i < 6 ? [3, 2, 1] : [null]) h += `<span style="display:inline-block;text-align:center;width:${sz + 14}px">${badge(i, d, sz)}<br><small>${p[0]}${d ? ' ' + ['I', 'II', 'III'][d - 1] : ''}</small></span>`;
    });
    h += '</div>';
  }
  fs.writeFileSync(preview, h);
}

// Swift
const sw = (s) => JSON.stringify(s);
function swFill(fl) {
  if (fl[0] === 'solid') return `.solid(${sw(fl[1])}, ${fl[2]})`;
  if (fl[0] === 'lin') return `.linear([${fl[1].map(sw).join(', ')}])`;
  return `.radial([${fl[1].map(([h, a]) => `(${sw(h)}, ${a})`).join(', ')}])`;
}
function swTag(l) {
  let t = '';
  if (l.part) t += `, part: ${l.part}, px: ${f(l.px)}, py: ${f(l.py)}`;
  if (l.part && l.i) t += `, i: ${l.i}`;
  if (l.m) t += ', m: true';
  if (l.clip) t += ', clip: true';
  return t;
}
function swLayers(ls, ind) {
  return '[\n' + ls.map((l) => `${ind}ArtLayer(${sw(l.d)}, ${swFill(l.fill)}${l.stroke ? `, stroke: ${sw(l.stroke)}, width: ${l.sw}` : ''}${swTag(l)})`).join(',\n') + '\n' + ind.slice(4) + ']';
}
let out = `// 自動產生，請勿手改：node scripts/art/badges.js\n// 牌位獎章形狀（120×120 座標），每階一組圖層。\n\nenum RankBadgeArt {\n`;
out += `    /// tiers[階][華麗程度]：有小段的階 [III, II, I]，大師、王者只有一組\n    static let tiers: [[[ArtLayer]]] = [\n` + tiers.map((t) => '        [\n' + t.map((v) => '            ' + swLayers(v, '                ')).join(',\n') + '\n        ]').join(',\n') + '\n    ]\n\n';
out += `    static let ribbons: [[ArtLayer]] = [\n` + PAL.map((_, i) => '        ' + swLayers(ribbon(i), '            ')).join(',\n') + '\n    ]\n\n';
out += `    /// numerals[n] = 羅馬數字 n（1 = I … 3 = III）；numerals[0] 為空\n    static let numerals: [[ArtLayer]] = [\n` + [0, 1, 2, 3].map((n) => '        ' + (n === 0 ? '[]' : swLayers(numerals(n), '            '))).join(',\n') + '\n    ]\n\n';
out += `    /// motion[階]：各部位的動作（見 badges.js 的 MOTION）\n    static let motion: [[BadgeOp]] = [\n` +
  MOTION.map((m) => '        [' + m.map((o) => `BadgeOp(${o.part}, ${o.kind}, ${o.a}, ${o.p}, ${o.st})`).join(', ') + ']').join(',\n') + '\n    ]\n\n';
out += `    /// particles[階]：粒子效果（見 badges.js 的 PARTICLES）\n    static let particles: [[BadgeParticles]] = [\n` +
  PARTICLES.map((m) => '        [' + m.map((q) => `BadgeParticles(${q.k}, ${q.n}, ${sw(q.c)}, ${sw(q.c2)}, ${q.s}, ${q.p}, ${q.r}, ${q.h}, ${q.y})`).join(', ') + ']').join(',\n') + '\n    ]\n\n';
out += `    /// sheen[階]：反光掃過（週期秒數, 強度）\n    static let sheen: [(Double, Double)] = [${SHEEN.map(([a, b]) => `(${a}, ${b})`).join(', ')}]\n}\n`;
fs.writeFileSync(path.join(__dirname, '../../Workout/Rank/RankBadgeArt.swift'), out);
