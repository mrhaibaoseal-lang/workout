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
const solid = (h, a = 1) => ['solid', h, a];
const lin = (...hs) => ['lin', hs];
const rad = (h, a0, a1 = 0) => ['rad', [[h, a0], [h, a1]]];

// 中央圖案
function emblem(kind, lt, md, dk) {
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
    out.push(L(d, solid(i % 2 ? md : lt), dk, sw));
  }
  return out;
}
const both = (layers) => [...layers, ...layers.map((l) => ({ ...l, d: mirrorD(l.d) }))];

// lv：小段華麗程度，0 = III、1 = II、2 = I（大師、王者固定 2）。越高的小段多一些外框裝飾，輪廓跟著變大。
function tierLayers(ti, lv = 2) {
  const [, lt, md, dk] = PAL[ti];
  const o = [];
  const metal = lin(lt, md, dk);
  const W = '#FFFFFF';
  switch (ti) {
    case 0: { // 鐵：八角鐵板＋鉚釘＋刮痕；II 加兩側鐵夾板，I 再加頂端三根鐵刺
      if (lv >= 2) {
        for (const [x, h, w] of [[60, 16, 5], [47, 10, 4], [73, 10, 4]]) {
          o.push(L(P([[x - w, 26], [x, 26 - h], [x + w, 26]]), metal, dk, 1.4));
        }
      }
      if (lv >= 1) {
        const plate = [L(P([[86, 46], [100, 49], [100, 67], [86, 70]]), metal, dk, 1.5),
          L(circle(95, 58, 2.2), solid(lt), dk, 1)];
        o.push(...both(plate));
      }
      const oct = regular(60, 58, 36, 8, -67.5);
      o.push(L(P(oct), solid(dk)));
      o.push(L(P(regular(60, 58, 32, 8, -67.5)), metal, dk, 1.5));
      o.push(L(P(regular(60, 58, 24, 8, -67.5)), solid(dk, 0.35)));
      for (const [x, y] of regular(60, 58, 28, 8, -67.5)) o.push(L(circle(x, y, 2.4), solid(lt), dk, 1));
      o.push(L('M40 40 L47 45', solid(W, 0), W, 1));
      o.push(L(circle(60, 59, 16), solid(dk, 0.0)));
      o.push(...emblem('dumbbell', lt, md, dk));
      break;
    }
    case 1: { // 銅：齒輪圓章＋月桂＋緞帶尾
      o.push(L(P([[44, 80], [36, 108], [44, 103], [50, 110], [54, 82]]), solid(md), dk, 1.5));
      o.push(L(mirrorD(P([[44, 80], [36, 108], [44, 103], [50, 110], [54, 82]])), solid(md), dk, 1.5));
      const leaves = [];
      for (let i = 0; i < [3, 5, 6][lv]; i++) {
        const a = (200 - i * 22) * Math.PI / 180;
        const cx = 60 + 39 * Math.cos(a), cy = 60 - 39 * Math.sin(a);
        leaves.push(L(ellipseRot(cx, cy, 3.6, 8, -((200 - i * 22) - 90) + 35), lin('#CFE8A0', '#5E8A2E'), '#2E4A12', 1.2));
      }
      o.push(...both(leaves));
      if (lv >= 2) o.push(L(P(star(60, 13, 5, 9, 3.8)), lin('#FFFFFF', lt, md), dk, 1.4));
      const cog = [];
      for (let i = 0; i < 32; i++) {
        const r = i % 4 < 2 ? 33 : 29, a = (i / 32 * 360 + 5.6) * Math.PI / 180;
        cog.push([60 + r * Math.cos(a), 58 + r * Math.sin(a)]);
      }
      o.push(L(P(cog), metal, dk, 1.8));
      o.push(L(circle(60, 58, 24), lin(md, dk), lt, 1.5));
      o.push(...emblem('kettlebell', lt, md, dk));
      break;
    }
    case 2: { // 銀：盾牌＋交叉雙劍
      const sword = (flip) => {
        const s = [L(P([[6, 10], [10, 4], [17, 7], [86, 82], [80, 88]]), lin(W, md), dk, 1.4),
          L(P([[11, 7], [83, 85]]), solid(W, 0), dk, 1),
          L(P([[74, 88], [88, 74], [92, 78], [78, 92]]), solid(GOLD[1]), GOLD[2], 1.2),
          L(P([[84, 86], [88, 82], [100, 96], [96, 100]]), solid('#5A3B22'), GOLD[2], 1.2),
          L(circle(99, 99, 3.5), solid(GOLD[1]), GOLD[2], 1.2)];
        return flip ? s.map((l) => ({ ...l, d: mirrorD(l.d) })) : s;
      };
      o.push(...sword(false), ...sword(true));
      if (lv >= 1) o.push(L(P([[60, 2], [66, 14], [62, 13], [60, 20], [58, 13], [54, 14]]), lin(W, md), dk, 1.4));
      if (lv >= 2) o.push(...both([L(P(star(16, 22, 4, 7, 2.2)), solid(W), dk, 0.8), L(P(star(22, 46, 4, 5, 1.6)), solid(W))]));
      const sh = 'M60 18 Q76 26 90 24 L90 58 Q90 84 60 100 Q30 84 30 58 L30 24 Q44 26 60 18 Z';
      o.push(L(sh, solid(dk)));
      o.push(L('M60 23 Q75 30 86 28.5 L86 58 Q86 81 60 95 Q34 81 34 58 L34 28.5 Q45 30 60 23 Z', metal, null));
      o.push(L('M60 23 L60 95 Q34 81 34 58 L34 28.5 Q45 30 60 23 Z', solid(W, 0.22)));
      o.push(L('M60 30 L80 34 L80 58 Q80 76 60 88 Q40 76 40 58 L40 34 Z', solid(W, 0), W, 1.2));
      o.push(...emblem('barbell', lt, md, dk));
      break;
    }
    case 3: { // 金：太陽光芒＋圓牌＋翅膀
      if (lv >= 1) o.push(...both(feathers(lv + 2, 82, 50, 28 + lv * 3, 30, lt, md, dk)));
      if (lv >= 2) o.push(L(P(star(60, 8, 5, 8, 3.4)), solid(W), GOLD[2], 1.2));
      o.push(L(P(star(60, 58, 12, 40, 28, -90)), lin(GOLD[0], GOLD[1]), GOLD[2], 1.5));
      o.push(L(circle(60, 58, 27), solid(dk)));
      o.push(L(circle(60, 58, 24), metal, lt, 1.5));
      o.push(L(circle(60, 58, 18), solid(dk, 0.25)));
      o.push(...emblem('star', lt, md, dk));
      break;
    }
    case 4: { // 白金：六角水晶框＋水晶碎片翼
      const shard = [L(P([[80, 44], [112, 30], [92, 52]]), lin(W, md), dk, 1.5),
        L(P([[84, 56], [116, 56], [88, 66]]), lin(lt, md), dk, 1.5),
        L(P([[82, 68], [104, 84], [80, 76]]), lin(lt, dk), dk, 1.5)];
      o.push(...both(shard.slice(0, 1 + lv)));
      if (lv >= 2) o.push(L(P([[60, 2], [66, 20], [60, 24], [54, 20]]), lin(W, md), dk, 1.4));
      const hx = regular(60, 58, 36, 6);
      o.push(L(P(hx), solid(dk)));
      const hi = regular(60, 58, 32, 6);
      for (let i = 0; i < 6; i++) {
        const sh = [lt, W, md, dk, md, lt][i];
        o.push(L(P([[60, 58], hi[i], hi[(i + 1) % 6]]), solid(sh)));
      }
      o.push(L(P(regular(60, 58, 21, 6)), lin(md, dk), lt, 1.5));
      o.push(...emblem('hexgem', lt, md, dk).map((l) => ({ ...l, d: l.d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _, y) => `${x} ${f(Number(y) - 1)}`) })));
      break;
    }
    case 5: { // 鑽石：大菱形＋水晶刺＋羽翼
      o.push(...both(feathers([2, 4, 5][lv], 84, 50, [26, 32, 36][lv], 34, lt, md, dk)));
      if (lv >= 2) o.push(...both([L(P(star(14, 24, 4, 7, 2)), solid(W)), L(P(star(108, 88, 4, 5, 1.5)), solid(W))]));
      for (const [pts] of [[[[60, 2], [66, 16], [54, 16]]], [[[38, 10], [48, 22], [41, 24]]], [[[82, 10], [79, 24], [72, 22]]]].slice(0, lv >= 1 ? 3 : 1)) {
        o.push(L(P(pts), lin(W, md), dk, 1.4));
      }
      const dia = [[60, 12], [98, 56], [60, 104], [22, 56]];
      o.push(L(P(dia), solid(dk)));
      const di = [[60, 18], [92, 56], [60, 98], [28, 56]];
      const c = [60, 56];
      o.push(L(P([di[0], di[1], c]), solid(W)));
      o.push(L(P([di[1], di[2], c]), solid(md)));
      o.push(L(P([di[2], di[3], c]), solid(dk)));
      o.push(L(P([di[3], di[0], c]), solid(lt)));
      o.push(L(P([[60, 34], [76, 56], [60, 80], [44, 56]]), solid(dk, 0.55), lt, 1.2));
      o.push(...emblem('brilliant', lt, md, dk).map((l) => ({ ...l, d: l.d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _, y) => `${x} ${f(Number(y) - 3)}`) })));
      break;
    }
    case 6: { // 大師：星形徽章＋大翼＋皇冠＋紫色光環
      o.push(L(circle(60, 58, 58), rad(md, 0.85)));
      o.push(...both(feathers(6, 80, 46, 42, 40, lt, md, dk)));
      o.push(L(P(star(60, 60, 5, 40, 22)), solid(dk)));
      o.push(L(P(star(60, 60, 5, 35, 19)), metal, lt, 1.2));
      o.push(L(circle(60, 61, 16), solid(dk)));
      o.push(...emblem('eye', lt, md, dk).map((l) => ({ ...l, d: l.d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _, y) => `${x} ${f(Number(y) + 2)}`) })));
      o.push(...crown('#B07CFF'));
      for (const [x, y, r] of [[18, 92, 3], [102, 92, 3], [10, 30, 2.4], [110, 30, 2.4]]) o.push(L(P(star(x, y, 4, r * 2, r * 0.6)), solid(W)));
      break;
    }
    case 7: { // 王者：火焰盾＋巨翼＋寶石皇冠＋光芒
      o.push(L(circle(60, 58, 60), rad('#FFB347', 0.9)));
      const rays = [];
      for (let i = 0; i < 16; i++) {
        const a = i / 16 * 2 * Math.PI, h = Math.PI / 16 * 0.4, R = 60;
        rays.push(P([[60, 58], [60 + R * Math.cos(a - h), 58 + R * Math.sin(a - h)], [60 + R * Math.cos(a + h), 58 + R * Math.sin(a + h)]]));
      }
      o.push(L(rays.join(' '), solid('#FFE6A0', 0.45)));
      o.push(...both(feathers(6, 80, 46, 44, 44, lt, md, dk)));
      // 火焰：盾外圈的火舌
      const fl = [];
      for (let i = 0; i < 9; i++) {
        const t = i / 8, x = 30 + t * 60;
        const base = 40 + Math.abs(t - 0.5) * 34;
        const h = 32 - Math.abs(t - 0.5) * 20;
        fl.push(`M${f(x - 7)} ${f(base + 8)} Q${f(x - 6)} ${f(base - h * 0.4)} ${f(x + (t < 0.5 ? -3 : 3))} ${f(base - h)} Q${f(x + 6)} ${f(base - h * 0.4)} ${f(x + 7)} ${f(base + 8)} Z`);
      }
      o.push(L(fl.join(' '), lin('#FFF3A0', '#FF8A1F', '#E0301E'), '#7A1408', 1.2));
      const sh = 'M60 26 Q76 32 90 30 L90 60 Q90 86 60 102 Q30 86 30 60 L30 30 Q44 32 60 26 Z';
      o.push(L(sh, solid(dk)));
      o.push(L('M60 31 Q75 36 86 34.5 L86 60 Q86 83 60 97 Q34 83 34 60 L34 34.5 Q45 36 60 31 Z', metal));
      o.push(L('M60 31 L60 97 Q34 83 34 60 L34 34.5 Q45 36 60 31 Z', solid(W, 0.2)));
      o.push(L('M60 38 L80 41 L80 60 Q80 78 60 90 Q40 78 40 60 L40 41 Z', solid(GOLD[1], 0), GOLD[0], 1.5));
      o.push(...emblem('trophy', lt, md, dk).map((l) => ({ ...l, d: l.d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _, y) => `${x} ${f(Number(y) + 4)}`) })));
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
  return o;
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
if (preview) {
  let h = '<!doctype html><meta charset=utf-8><body style="background:#0E1116;color:#ccc;font-family:sans-serif;margin:0;padding:10px">';
  for (const sz of [150, 58, 44]) {
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
function swLayers(ls, ind) {
  return '[\n' + ls.map((l) => `${ind}ArtLayer(${sw(l.d)}, ${swFill(l.fill)}${l.stroke ? `, stroke: ${sw(l.stroke)}, width: ${l.sw}` : ''})`).join(',\n') + '\n' + ind.slice(4) + ']';
}
let out = `// 自動產生，請勿手改：node scripts/art/badges.js\n// 牌位獎章形狀（120×120 座標），每階一組圖層。\n\nenum RankBadgeArt {\n`;
out += `    /// tiers[階][華麗程度]：有小段的階 [III, II, I]，大師、王者只有一組\n    static let tiers: [[[ArtLayer]]] = [\n` + tiers.map((t) => '        [\n' + t.map((v) => '            ' + swLayers(v, '                ')).join(',\n') + '\n        ]').join(',\n') + '\n    ]\n\n';
out += `    static let ribbons: [[ArtLayer]] = [\n` + PAL.map((_, i) => '        ' + swLayers(ribbon(i), '            ')).join(',\n') + '\n    ]\n\n';
out += `    /// numerals[n] = 羅馬數字 n（1 = I … 3 = III）；numerals[0] 為空\n    static let numerals: [[ArtLayer]] = [\n` + [0, 1, 2, 3].map((n) => '        ' + (n === 0 ? '[]' : swLayers(numerals(n), '            '))).join(',\n') + '\n    ]\n}\n';
fs.writeFileSync(path.join(__dirname, '../../Workout/Rank/RankBadgeArt.swift'), out);
