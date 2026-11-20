// 裝備造型產生器：每件裝備在身體某個部位的局部座標裡畫什麼。
// node scripts/art/gear.js [預覽.html] → 產生 Workout/Character/GearArt.swift（與預覽）。
//
// 局部座標（單位＝畫布單位，y 正向＝前面／上面）：
//   torso  原點髖部，x 沿髖→肩（約 50），y 朝胸前
//   nape   原點肩部，x 沿髖→肩，y 朝胸前（披風、背負物用，會隨時間擺動）
//   thigh  原點髖→膝（約 36）；shin 膝→踝（約 36）；foot 踝→腳尖（約 16），y 朝上
//   upper  肩→肘；fore 肘→手（約 24）；fist 原點在手，x 沿肘→手方向
//   grip   原點在手，不旋轉，x 朝右、y 朝上（啞鈴用；高腳杯深蹲時轉 90 度）
// 圖層 z：back＝身體外框之前；limb＝畫完該肢段之後（遠側肢段也畫一份，較暗）；
//        over＝全部肢段之後、頭之前；grip＝頭之後（啞鈴）
const fs = require('fs');
const path = require('path');

const f = (n) => (Math.round(n * 10) / 10).toString();
const K = '#0A0D12';
const W = '#FFFFFF';
const P = (pts, close = true) => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join(' L') + (close ? ' Z' : '');
const circle = (cx, cy, r) => {
  const k = 0.5523 * r;
  return `M${f(cx)} ${f(cy - r)} C${f(cx + k)} ${f(cy - r)} ${f(cx + r)} ${f(cy - k)} ${f(cx + r)} ${f(cy)}` +
    ` C${f(cx + r)} ${f(cy + k)} ${f(cx + k)} ${f(cy + r)} ${f(cx)} ${f(cy + r)}` +
    ` C${f(cx - k)} ${f(cy + r)} ${f(cx - r)} ${f(cy + k)} ${f(cx - r)} ${f(cy)}` +
    ` C${f(cx - r)} ${f(cy - k)} ${f(cx - k)} ${f(cy - r)} ${f(cx)} ${f(cy - r)} Z`;
};
const ellipse = (cx, cy, rx, ry) => {
  const kx = 0.5523 * rx, ky = 0.5523 * ry;
  return `M${f(cx)} ${f(cy - ry)} C${f(cx + kx)} ${f(cy - ry)} ${f(cx + rx)} ${f(cy - ky)} ${f(cx + rx)} ${f(cy)}` +
    ` C${f(cx + rx)} ${f(cy + ky)} ${f(cx + kx)} ${f(cy + ry)} ${f(cx)} ${f(cy + ry)}` +
    ` C${f(cx - kx)} ${f(cy + ry)} ${f(cx - rx)} ${f(cy + ky)} ${f(cx - rx)} ${f(cy)}` +
    ` C${f(cx - rx)} ${f(cy - ky)} ${f(cx - kx)} ${f(cy - ry)} ${f(cx)} ${f(cy - ry)} Z`;
};
const rrect = (x, y, w, h, r) => {
  r = Math.min(r, w / 2, h / 2);
  return `M${f(x + r)} ${f(y)} L${f(x + w - r)} ${f(y)} Q${f(x + w)} ${f(y)} ${f(x + w)} ${f(y + r)}` +
    ` L${f(x + w)} ${f(y + h - r)} Q${f(x + w)} ${f(y + h)} ${f(x + w - r)} ${f(y + h)}` +
    ` L${f(x + r)} ${f(y + h)} Q${f(x)} ${f(y + h)} ${f(x)} ${f(y + h - r)}` +
    ` L${f(x)} ${f(y + r)} Q${f(x)} ${f(y)} ${f(x + r)} ${f(y)} Z`;
};
const star = (cx, cy, n, ro, ri, rot = 90) => {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const r = i % 2 ? ri : ro, a = (rot + i * 180 / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return P(pts);
};
const line = (pts) => P(pts, false);

// 圖層
const L = (d, fill, stroke = null, sw = 0, blur = 0) => ({ d, fill, stroke, sw, blur });
const solid = (h, a = 1) => ['solid', h, a];
const lin = (...hs) => ['lin', hs];
const none = solid('#000000', 0);
const glowLine = (d, col, w) => [L(d, none, col, w + 2.5, 2.5), L(d, none, col, w), L(d, none, W, Math.max(0.8, w * 0.35))];
const glowFill = (d, col) => [L(d, solid(col), null, 0, 2.5), L(d, solid(col), K, 1.4)];

// part：{anchor, z, layers, far?: 是否也畫在遠側肢段}
const part = (anchor, z, layers, far = false) => ({ anchor, z, layers, far });

const SERIES = {
  basic: { c1: '#3E4652', c2: '#F4F5F7', c3: '#9AA4AF' },
  street: { c1: '#2F6FE0', c2: '#F4F5F7', c3: '#FFCC33' },
  neon: { c1: '#141A24', c2: '#19E3FF', c3: '#FF3DCB' },
  lava: { c1: '#2A1A16', c2: '#FF5A1F', c3: '#FFC23D' },
  frost: { c1: '#DDF4FF', c2: '#4FB8FF', c3: '#FFFFFF' },
  gold: { c1: '#F2B630', c2: '#FFF1B8', c3: '#C8302C' },
  shadow: { c1: '#1A1424', c2: '#9B5CFF', c3: '#E2D4FF' },
  titan: { c1: '#8C98A8', c2: '#31F2D4', c3: '#2A3340' },
  night: { c1: '#1C2230', c2: '#FF8A1F', c3: '#3B4558' },
  dawn: { c1: '#EEF3FA', c2: '#E0A21B', c3: '#2E6BFF' },
  rune: { c1: '#2C2F3A', c2: '#3DF5A0', c3: '#C9A86A' },
  astral: { c1: '#22184A', c2: '#FF6BD6', c3: '#8FE3FF' },
};
const GOLD = ['#FFF1B8', '#F2B630', '#8A5A00'];

// ===================== 啞鈴（grip） =====================
// 橫放的啞鈴，握把在手上。x -15..15
function bellArt(id) {
  const s = SERIES[id];
  const bar = (c) => L(rrect(-9, -1.6, 18, 3.2, 1.2), solid(c), K, 1.6);
  const pair = (fn) => [...fn(-1), ...fn(1)];
  switch (id) {
    case 'basic': // 六角鑄鐵
      return [bar('#9AA4AF'), ...pair((sg) => [L(P([[sg * 8, -5], [sg * 9.5, -7.5], [sg * 14.5, -7.5], [sg * 16, -5], [sg * 16, 5], [sg * 14.5, 7.5], [sg * 9.5, 7.5], [sg * 8, 5]]), lin('#4A525E', '#1B2027'), K, 2), L(line([[sg * 12, -7], [sg * 12, 7]]), none, '#6B7480', 1)])];
    case 'street': // 電鍍疊片
      return [bar('#E6EBF0'), ...pair((sg) => [L(rrect(sg > 0 ? 7.5 : -10.5, -8, 3, 16, 1.2), lin(W, '#9AA4AF'), K, 1.6), L(rrect(sg > 0 ? 10.5 : -14, -6.5, 3.5, 13, 1.2), lin(W, '#B9C2CC'), K, 1.6), L(rrect(sg > 0 ? 14 : -16.5, -4.5, 2.5, 9, 1), lin(W, '#C9D1DA'), K, 1.4)])];
    case 'neon':
      return [bar('#2A3340'), ...pair((sg) => [L(rrect(sg > 0 ? 8 : -16, -7, 8, 14, 3), solid('#141A24'), K, 2), ...glowLine(line([[sg * 12, -6], [sg * 12, 6]]), s.c2, 1.6)])];
    case 'lava': // 岩石塊＋裂縫
      return [bar('#3A2A26'), ...pair((sg) => [L(P([[sg * 8, -4], [sg * 10, -8], [sg * 15, -7], [sg * 17, -2], [sg * 16, 5], [sg * 12, 8], [sg * 8, 5]]), lin('#4A332C', '#1E1210'), K, 2), ...glowLine(line([[sg * 10, -5], [sg * 13, -1], [sg * 11, 2], [sg * 14, 6]]), s.c2, 1.2)])];
    case 'frost': // 冰塊
      return [bar('#BFE6FF'), ...pair((sg) => [L(rrect(sg > 0 ? 7.5 : -17.5, -7.5, 10, 15, 2), lin('#F2FBFF', '#7FCBFF'), '#1D5A8A', 1.8), L(P([[sg * 9.5, 5], [sg * 12, 5.5], [sg * 9.5, 1]]), solid(W, 0.9)), L(line([[sg * 14, -5], [sg * 15.5, -2]]), none, W, 1.2)])];
    case 'gold':
      return [bar(GOLD[1]), ...pair((sg) => [L(rrect(sg > 0 ? 8 : -16.5, -8, 8.5, 16, 3.5), lin(GOLD[0], GOLD[1], GOLD[2]), K, 2), L(star(sg * 12.2, 0, 5, 3.2, 1.4), solid(W))])];
    case 'shadow': // 虛空球
      return [bar('#2A2236'), ...pair((sg) => [L(circle(sg * 12, 0, 8), solid(s.c2, 0.8), null, 0, 3), L(circle(sg * 12, 0, 7), lin('#3A2A55', '#0A0610'), K, 2), L(circle(sg * 12, 0, 2.6), solid(s.c3)), L(circle(sg * 12, 0, 4.6), none, s.c2, 1)])];
    case 'titan': // 能量膠囊
      return [bar('#5A6676'), ...pair((sg) => [L(P([[sg * 8, -6], [sg * 10, -8], [sg * 15, -8], [sg * 17, -5], [sg * 17, 5], [sg * 15, 8], [sg * 10, 8], [sg * 8, 6]]), lin('#C2CBD6', '#5A6676'), K, 2), ...glowLine(rrect(sg > 0 ? 11 : -14, -5, 3, 10, 1.5), s.c2, 1)])];
    case 'night':
      return [bar('#2A303A'), ...pair((sg) => [L(rrect(sg > 0 ? 8 : -16, -7.5, 8, 15, 1.5), solid('#2A303A'), K, 2), L(rrect(sg > 0 ? 11 : -13, -7.5, 2, 15, 0), solid(s.c2))])];
    case 'dawn': // 太陽盤
      return [bar(GOLD[1]), ...pair((sg) => [L(star(sg * 12, 0, 8, 9.5, 6.5, 0), solid(s.c2), K, 1.5), L(circle(sg * 12, 0, 5.5), lin(W, '#E9EEF5'), K, 1.6)])];
    case 'rune': // 石塊＋符文
      return [bar('#6B5A3A'), ...pair((sg) => [L(rrect(sg > 0 ? 7.5 : -17.5, -8, 10, 16, 2), lin('#5A5E6A', '#2C2F3A'), K, 2), ...glowLine(line([[sg * 12.5, -5], [sg * 12.5, 5], [sg * 12.5, -1], [sg * 15, -4]]), s.c2, 1.2)])];
    case 'astral': // 星形頭
      return [bar('#8FE3FF'), ...pair((sg) => [L(star(sg * 12.5, 0, 5, 9, 4), solid(s.c2, 0.8), null, 0, 2.5), L(star(sg * 12.5, 0, 5, 8.5, 3.8), lin(W, sg > 0 ? s.c2 : s.c3), K, 1.6)])];
  }
  return defaultBell();
}
function defaultBell() {
  return [L(rrect(-9, -1.5, 18, 3, 1.2), solid('#8D98A4'), K, 1.5),
    L(rrect(7.5, -6.5, 6, 13, 2), solid('#3E4652'), K, 2), L(rrect(-13.5, -6.5, 6, 13, 2), solid('#3E4652'), K, 2)];
}

// ===================== 鞋（foot，踝→腳尖 約 16，y 朝上） =====================
function sole(c, h = 3, x0 = -7, x1 = 22) {
  return L(`M${x0} -3 L${x1} -3 Q${x1 + 2.5} -4.5 ${x1} ${-3 - h} L${x0 + 1} ${-3 - h} Q${x0 - 1.5} ${-4.5 - h / 3} ${x0} -3 Z`, solid(c), K, 1.8);
}
function feetArt(id) {
  const s = SERIES[id];
  const low = (c) => L('M-6 -3 Q-8 6 -2 9 L5 9 Q9 5 14 4 Q21 2 21 -1 L21 -3 Z', solid(c), K, 2.2);
  const parts = [];
  switch (id) {
    case 'basic':
      parts.push(low('#F4F5F7'), sole('#C9D1DA', 2.5), L(line([[3, 7], [6, 3.5]]), none, '#9AA4AF', 1.2), L(line([[6, 7.5], [9, 4.5]]), none, '#9AA4AF', 1.2));
      break;
    case 'street': // 高筒籃球鞋
      parts.push(L('M-7 -3 Q-8 14 -5 16 L6 16 Q7 8 10 5 Q20 3 21 0 L21 -3 Z', solid(s.c1), K, 2.2), sole(W, 4), L('M-3 3 Q6 5 14 1', none, W, 2.2), L(star(1, 11, 5, 3, 1.3), solid(s.c3), K, 1), L(rrect(-7, 13, 13, 3.5, 1.5), solid(W), K, 1.4));
      break;
    case 'neon':
      parts.push(low('#1B2230'), ...glowLine(line([[-6, -4.5], [22, -4.5]]), s.c3, 2), ...glowLine(line([[-3, 4], [8, 7]]), s.c2, 1.1));
      break;
    case 'lava': // 戰靴＋鞋跟火焰
      parts.push(L('M-11 -2 Q-18 3 -14 8 Q-13 3 -8 3 Z M-10 -5 Q-20 -6 -17 0 Q-14 -3 -7 -1 Z', lin(s.c3, s.c2), null, 0, 0), L('M-11 -2 Q-18 3 -14 8 Q-13 3 -8 3 Z M-10 -5 Q-20 -6 -17 0 Q-14 -3 -7 -1 Z', solid(s.c2, 0.8), null, 0, 2.5),
        L('M-7 -3 Q-8 14 -6 17 L6 17 Q6 8 10 6 Q21 4 22 -1 L22 -3 Z', lin('#4A332C', '#1E1210'), K, 2.2), sole('#140A08', 4), ...glowLine(line([[-3, 14], [0, 9], [-2, 6], [3, 2]]), s.c2, 1.1), ...glowLine(line([[10, 4], [14, 1.5]]), s.c3, 1));
      break;
    case 'frost': // 冰刀鞋
      parts.push(L('M-6 -3 Q-8 14 -5 16 L6 16 Q7 8 10 5 Q20 3 21 0 L21 -3 Z', solid(W), '#1D5A8A', 2.2),
        L(P([[-3, -3], [-3, -7], [18, -7], [18, -3]]), solid('#9AA4AF'), K, 1.5),
        L('M-6 -7 L22 -7 Q26 -8 24 -11 L-6 -11 Q-8 -9 -6 -7 Z', lin(W, s.c2), '#1D5A8A', 1.6),
        L(line([[0, 13], [4, 10], [0, 7]]), none, s.c2, 1.4), L(rrect(-7, 13, 14, 4, 2), solid('#CFEFFF'), '#1D5A8A', 1.4));
      break;
    case 'gold': // 金靴＋腳踝小翅膀
      parts.push(L('M-6 -3 Q-8 16 -5 19 L7 19 Q7 8 10 6 Q21 4 22 -1 L22 -3 Z', lin(GOLD[0], GOLD[1]), K, 2.2), sole(GOLD[2], 3),
        L('M-5 13 Q-16 22 -22 18 Q-15 17 -17 13 Q-12 15 -10 10 Z', lin(W, GOLD[0]), K, 1.6), L(rrect(-7, 17, 15, 4, 2), solid(GOLD[1]), K, 1.5));
      break;
    case 'shadow': // 分趾忍者鞋＋綁帶
      parts.push(L('M-6 -3 Q-8 10 -4 13 L5 13 Q9 6 13 4 Q16 3 17 1 Q19 4 22 1 L22 -3 Z', solid('#120E1A'), K, 2.2), L(line([[16.5, 1], [16.5, -3]]), none, '#3A2A55', 1.4),
        L(line([[-5, 10], [5, 6]]), none, s.c2, 1.6), L(line([[-5, 5], [7, 2]]), none, s.c2, 1.6), sole('#0A0610', 2));
      break;
    case 'titan': // 推進靴：裝甲＋腳底噴焰
      parts.push(L('M-8 -12 Q2 -26 12 -12 Z', lin(W, s.c2), null, 0, 3), L('M-4 -10 Q2 -20 8 -10 Z', solid(W, 0.9)),
        L('M-7 -3 Q-9 14 -6 16 L7 16 Q7 8 11 6 Q22 4 23 -1 L23 -4 Z', lin('#C2CBD6', '#5A6676'), K, 2.2),
        L(rrect(-6, -9, 26, 6, 2), solid(s.c3), K, 1.8), ...glowLine(line([[-2, -6], [16, -6]]), s.c2, 1.2), L(line([[8, 4], [13, 2]]), none, K, 1.2));
      break;
    case 'night': // 戰術靴＋綁帶＋厚鞋底
      parts.push(L('M-7 -3 Q-9 14 -6 17 L6 17 Q6 8 10 6 Q21 4 22 -1 L22 -3 Z', solid('#232A36'), K, 2.2), sole('#0E1218', 4.5),
        L(line([[-6, -7.5], [-3, -5.5], [0, -7.5], [3, -5.5], [6, -7.5], [9, -5.5], [12, -7.5], [15, -5.5], [18, -7.5]]), none, '#3B4558', 1.2),
        L(rrect(-7, 5, 13, 2.6, 1), solid(s.c2), K, 1), L(rrect(-7, 11, 13, 2.6, 1), solid('#3B4558'), K, 1));
      break;
    case 'dawn': // 及膝英雄長靴（另外在小腿上加筒）
      parts.push(L('M-7 -3 Q-8 10 -6 12 L7 12 Q7 8 10 6 Q21 4 22 -1 L22 -3 Z', solid(s.c3), K, 2.2), sole('#1A3F99', 3));
      break;
    case 'rune': // 青銅戰靴＋鞋尖刺
      parts.push(L('M14 2 L27 4 L20 -2 Z', lin(W, s.c3), K, 1.6), L('M-7 -3 Q-9 14 -6 16 L7 16 Q7 8 10 6 Q20 4 21 -1 L21 -3 Z', lin('#E6D2A2', s.c3, '#6B5A3A'), K, 2.2), sole('#3A2E1E', 3),
        L(rrect(-7, 6, 14, 3, 1), solid('#6B5A3A'), K, 1.2), ...glowLine(line([[0, 13], [0, 10]]), s.c2, 1));
      break;
    case 'astral': // 尖頭捲曲巫師鞋
      parts.push(L('M-6 -3 Q-8 8 -3 10 L4 10 Q10 6 16 4 Q24 2 27 8 Q30 4 26 0 Q22 -3 18 -3 Z', lin(s.c3, '#5A45B0'), K, 2.2), L(circle(27.5, 8, 2), solid(s.c2), K, 1.2), L(star(5, 5, 4, 3, 1), solid(W)));
      break;
  }
  const out = [part('foot', 'limb', parts, true)];
  if (id === 'dawn') {
    // 長靴筒：小腿下半段
    out.push(part('shin', 'limb', [L('M14 -8 L38 -7.5 L38 7.5 L14 8 Q12 0 14 -8 Z', solid(s.c3), K, 2), L(rrect(12, -9, 5, 18, 2), solid(s.c2), K, 1.6)], true));
  }
  if (id === 'gold') {
    out.push(part('shin', 'limb', [L('M24 -7.5 L38 -7.5 L38 7.5 L24 7.5 Z', lin(GOLD[0], GOLD[1]), K, 1.8)], true));
  }
  return out;
}

// ===================== 手（fist：原點在手，x 沿肘→手） =====================
function handsArt(id) {
  const s = SERIES[id];
  const cuff = (c, x0 = -9, x1 = -1, w = 7) => L(rrect(x0, -w, x1 - x0, w * 2, 2), solid(c), K, 2);
  const fist = (c, r = 6.5) => [L(ellipse(1.5, 0, r, r - 0.5), solid(c), K, 2.2), L(line([[4, 3], [6.5, 1]]), none, K, 1.1), L(line([[4, -1.5], [6.5, -3]]), none, K, 1.1)];
  let p = [];
  switch (id) {
    case 'basic': // 護腕
      p = [L(rrect(-11, -7, 7, 14, 1.5), solid(W), K, 2), L(line([[-9.5, -6], [-9.5, 6]]), none, '#C9D1DA', 1)];
      break;
    case 'street': // 露指手套＋魔鬼氈
      p = [cuff('#E6EBF0', -9, -1), ...fist('#F4F5F7', 6), L(rrect(-7, -7.5, 4, 15, 1), solid(s.c1), K, 1.5), L(ellipse(5, 0, 2.6, 4.5), solid('#E9BE9C'), K, 1.2)];
      break;
    case 'neon': // 發光指節
      p = [cuff('#141A24', -10, 0), ...fist('#141A24', 6.5), ...glowLine(line([[5, -4], [5, 4]]), s.c2, 1.4), ...glowLine(line([[-8, -5.5], [-8, 5.5]]), s.c3, 1)];
      break;
    case 'lava': // 冒火的拳頭
      p = [L('M-2 -7 Q2 -16 8 -12 Q6 -9 10 -8 Q12 -13 15 -6 Q17 -2 14 2 Q20 0 16 8 Q12 10 8 8 Z', lin(s.c3, s.c2), null, 0, 0), L('M-2 -7 Q2 -16 8 -12 Q6 -9 10 -8 Q12 -13 15 -6 Q17 -2 14 2 Q20 0 16 8 Q12 10 8 8 Z', solid(s.c2, 0.8), null, 0, 3),
        cuff('#2A1A16', -10, 0, 7.5), ...fist('#3A2420', 7.5), ...glowLine(line([[1, -5], [4, -1], [2, 3]]), s.c2, 1)];
      break;
    case 'frost': // 冰晶手套
      p = [cuff(W, -10, -1, 7.5), ...fist('#CFEFFF', 7), L(P([[3, 6], [6, 13], [8, 5]]), lin(W, s.c2), '#1D5A8A', 1.2), L(P([[6, 3], [12, 8], [10, 1]]), lin(W, s.c2), '#1D5A8A', 1.2), L(P([[7, -2], [13, -3], [8, -5]]), lin(W, s.c2), '#1D5A8A', 1.2)];
      break;
    case 'gold': // 拳擊手套
      p = [L(rrect(-13, -8, 9, 16, 2), solid(W), K, 2), L(line([[-11, -7], [-11, 7]]), none, GOLD[1], 1.4),
        L('M-5 -9 Q2 -12 9 -9 Q15 -5 14 2 Q13 10 4 11 Q-4 11 -5 6 Z', lin(GOLD[0], GOLD[1], GOLD[2]), K, 2.4),
        L('M-3 6 Q2 3 6 7', none, K, 1.4), L(ellipse(4, -5, 3.5, 2), solid(W, 0.55))];
      break;
    case 'shadow': // 三爪
      p = [cuff('#1A1424', -10, 0), ...fist('#1A1424', 6.5),
        ...[[-4, 0], [0, 0.4], [4, 0.8]].map(([y]) => L(`M5 ${y - 1.5} Q16 ${y - 3} 22 ${y + 3} Q15 ${y + 1} 5 ${y + 1.5} Z`, lin(s.c3, s.c2), K, 1.4))];
      break;
    case 'titan': // 機械手甲
      p = [L(rrect(-12, -8.5, 13, 17, 3), lin('#C2CBD6', '#5A6676'), K, 2), L(line([[-6, -8], [-6, 8]]), none, K, 1.2),
        L(rrect(-1, -7.5, 12, 15, 4), lin('#C2CBD6', '#8C98A8'), K, 2.2), ...glowLine(line([[3, -5], [3, 5]]), s.c2, 1.2), L(circle(-9, 0, 2), solid(s.c2), K, 1)];
      break;
    case 'night': // 戰術手套＋護臂鰭片
      p = [L(rrect(-16, -7.5, 15, 15, 2), solid('#2A303A'), K, 2),
        ...[-14, -9, -4].map((x) => L(P([[x, -7], [x - 3, -14], [x + 3, -7]]), solid('#3B4558'), K, 1.5)),
        ...fist('#1C2230', 6.5), L(rrect(3, -5.5, 4, 11, 1.5), solid(s.c2), K, 1.2)];
      break;
    case 'dawn': // 長護腕＋星
      p = [L('M-16 -8 L-1 -7 L-1 7 L-16 8 Q-18 0 -16 -8 Z', solid(s.c2), K, 2), L(rrect(-17, -9, 4, 18, 1.5), solid(W), K, 1.4),
        L(star(-8, 0, 5, 4.5, 2), solid(W), K, 1), ...fist(s.c3, 6.5)];
      break;
    case 'rune': // 尖刺拳套
      p = [cuff('#6B5A3A', -10, 0, 7.5), ...[[-1, -6], [3, -6.5], [7, -5]].map(([x, y]) => L(P([[x - 2, y + 1], [x, y - 7], [x + 2, y + 1]]), lin(W, s.c3), K, 1.3)),
        ...fist(s.c3, 7), ...glowLine(line([[-6, -4], [-6, 4], [-6, 0], [-3, -3]]), s.c2, 1)];
      break;
    case 'astral': // 手上漂浮的星球
      p = [cuff(s.c1, -10, 0), ...fist(s.c1, 6.2), L(circle(13, 8, 6), solid(s.c2, 0.85), null, 0, 3), L(circle(13, 8, 4.6), lin(W, s.c3), K, 1.4),
        L(ellipse(13, 8, 8, 2), none, s.c2, 1.2)];
      break;
  }
  return [part('fist', 'limb', p, true)];
}

// ===================== 上衣（torso：原點髖，x 往肩 約 50，y 朝胸前） =====================
// 軀幹在 x 處的半寬約 10 + 6 * x / 50
const hw = (x) => 10 + 6 * x / 50;
function topArt(id) {
  const s = SERIES[id];
  const out = [];
  switch (id) {
    case 'basic': // 背心：領口與袖孔
      out.push(part('torso', 'limb', [L(`M42 ${f(hw(42))} Q36 6 44 0`, none, '#2A303A', 2), L(`M30 ${f(-hw(30))} Q40 -8 46 -4`, none, '#2A303A', 1.6)]));
      break;
    case 'street': // 帽 T：背後帽子、口袋、抽繩
      out.push(part('nape', 'over', [L('M4 -6 Q16 -10 12 -22 Q4 -28 -6 -20 Q-10 -12 -4 -8 Z', solid(s.c1), K, 2.6), L('M2 -10 Q9 -13 7 -19', none, '#1D4FA8', 2)]));
      out.push(part('torso', 'limb', [L(rrect(6, 2, 16, 11, 4), solid('#2558B8'), K, 1.6), L(line([[44, 8], [34, 9]]), none, W, 1.6), L(line([[44, 4], [32, 5]]), none, W, 1.6),
        L(circle(33.5, 9, 1.4), solid(W)), L(circle(31.5, 5, 1.4), solid(W)), L(rrect(0, -11, 4, 22, 1), solid('#2558B8'))]));
      break;
    case 'neon': // 電路紋
      out.push(part('torso', 'limb', [...glowLine(line([[6, 4], [18, 4], [24, 9], [40, 9]]), s.c2, 1.2), ...glowLine(line([[12, -4], [28, -4], [34, 2], [44, 2]]), s.c3, 1.1),
        L(circle(40, 9, 2.2), solid(s.c2), K, 1), L(circle(44, 2, 2.2), solid(s.c3), K, 1)]));
      break;
    case 'lava': // 岩漿裂紋
      out.push(part('torso', 'limb', [...glowLine(line([[4, 6], [12, 2], [10, -4], [18, -8]]), s.c2, 1.4), ...glowLine(line([[22, 10], [28, 4], [26, -2], [36, -6], [42, 0]]), s.c3, 1.2), ...glowLine(line([[30, 12], [36, 8]]), s.c2, 1)]));
      break;
    case 'frost': // 毛領＋雪花
      out.push(part('torso', 'over', [...[[-12, 0], [-8, 1], [-3, 1.5], [2, 1.5], [7, 1], [12, 0]].map(([y, dx]) => L(circle(48 + dx, y, 4.2), solid(W), '#1D5A8A', 1.3))]));
      out.push(part('torso', 'limb', [L(line([[22, 0], [34, 0]]), none, s.c2, 1.8), L(line([[24, -5], [32, 5]]), none, s.c2, 1.8), L(line([[24, 5], [32, -5]]), none, s.c2, 1.8), L(circle(28, 0, 2), solid(W), s.c2, 1)]));
      break;
    case 'gold': // 金鍊＋大獎牌
      out.push(part('torso', 'over', [L(line([[48, -10], [40, -4], [30, 4], [26, 12]]), none, GOLD[2], 3.8), L(line([[48, -10], [40, -4], [30, 4], [26, 12]]), none, GOLD[1], 2.2),
        L(circle(24, 13, 6.5), lin(GOLD[0], GOLD[1], GOLD[2]), K, 2), L(star(24, 13, 5, 3.6, 1.6), solid(W))]));
      break;
    case 'shadow': // 圍巾＋飄尾
      out.push(part('nape', 'back', [L('M2 -6 Q-6 -24 -2 -40 Q4 -30 6 -22 Q8 -14 6 -6 Z', lin(s.c2, '#4A2A80'), K, 2), L('M0 -8 Q-12 -20 -12 -34 Q-4 -26 4 -10 Z', lin(s.c2, '#2A1A44'), K, 1.6)], false));
      out.push(part('torso', 'over', [L(rrect(44, -14, 9, 28, 4), lin(s.c2, '#4A2A80'), K, 2), L(line([[46, -12], [46, 12]]), none, s.c3, 1)]));
      out.push(part('torso', 'limb', [L(line([[42, -10], [8, 10]]), none, '#2A2236', 4), L(line([[42, -10], [8, 10]]), none, s.c2, 1.2)]));
      break;
    case 'titan': // 胸甲＋腹甲
      out.push(part('torso', 'limb', [L(`M28 ${f(hw(28) + 1)} L46 ${f(hw(46) + 1)} L48 -4 L30 -6 Z`, lin('#C2CBD6', '#5A6676'), K, 2),
        ...[4, 11, 18].map((x) => L(rrect(x, 2, 6, hw(x) - 1, 2), solid('#8C98A8'), K, 1.4)), ...glowLine(line([[24, -8], [24, 8]]), s.c2, 0.8)]));
      break;
    case 'night': // 戰術背心：腰包＋斜背帶
      out.push(part('torso', 'limb', [L(line([[46, 8], [6, -10]]), none, K, 5), L(line([[46, 8], [6, -10]]), none, '#3B4558', 3),
        L(rrect(2, 4, 9, 8, 1.5), solid('#2A303A'), K, 1.5), L(rrect(2, -6, 9, 8, 1.5), solid('#2A303A'), K, 1.5), L(rrect(0, -12, 4, 24, 1), solid(s.c2), K, 1),
        L(rrect(30, 6, 8, 7, 1.5), solid('#2A303A'), K, 1.5)]));
      break;
    case 'dawn': // 高領＋金腰帶
      out.push(part('torso', 'limb', [L(rrect(0, -11, 6, 22, 2), lin(GOLD[0], s.c2), K, 1.6), L(rrect(0.5, 6, 5, 6, 1.5), solid(s.c3), K, 1.2)]));
      break;
    case 'rune': // 毛皮披肩＋符文腰帶
      out.push(part('torso', 'over', [L('M40 -16 Q52 -20 56 -8 Q58 4 52 14 Q46 18 40 15 Q44 0 40 -16 Z', lin('#A07850', '#5A3F26'), K, 2), L(line([[46, -10], [49, -4]]), none, '#3A2814', 1.2), L(line([[47, 4], [50, 9]]), none, '#3A2814', 1.2)]));
      out.push(part('torso', 'limb', [L(rrect(0, -11, 6, 22, 1.5), solid('#5A4A30'), K, 1.6), L(rrect(-0.5, 3, 7, 7, 1.5), solid(s.c3), K, 1.2), ...glowLine(line([[1.5, 5], [5, 8]]), s.c2, 0.8)]));
      break;
    case 'astral': // 法袍：長下襬＋高領
      out.push(part('torso', 'over', [L('M6 -12 L-34 -20 Q-36 -2 -34 16 L6 13 Z', lin(s.c1, '#3A2A70'), K, 2.2), L(line([[-33, -18], [-33, 15]]), none, s.c2, 2),
        L(star(-16, 0, 5, 3.5, 1.4), solid(s.c3)), L(star(-26, 9, 4, 2.5, 0.8), solid(s.c2)), L(star(-24, -10, 4, 2.2, 0.8), solid(s.c3)),
        L('M44 -13 Q54 -18 58 -12 L54 -2 Z', solid(s.c2), K, 1.8)]));
      break;
  }
  return out;
}

// ===================== 下身（thigh：原點髖往膝 約 36，y 朝前） =====================
function bottomArt(id) {
  const s = SERIES[id];
  const out = [];
  switch (id) {
    case 'basic':
      out.push(part('thigh', 'limb', [L(line([[20, -9], [20, 9]]), none, '#14181E', 2)], true));
      break;
    case 'street': // 寬鬆籃球褲＋側條
      out.push(part('thigh', 'limb', [L('M-4 -11 Q12 -13 25 -13.5 Q27.5 0 26 12.5 Q12 12 -4 11 Z', solid(W), K, 2.2), L(line([[0, -11], [24, -12.5]]), none, s.c1, 3), L(line([[23, -12], [24, 11]]), none, s.c1, 2)], true));
      break;
    case 'neon': // 膝燈＋褲管發光
      out.push(part('shin', 'limb', [L(circle(1, 7, 3.6), solid(s.c3), null, 0, 2.5), L(circle(1, 7, 3), solid(s.c3), K, 1.2), L(circle(1, 7, 1.2), solid(W)), ...glowLine(line([[33, -7], [33, 7]]), s.c2, 1.2)], true));
      break;
    case 'lava': // 褲管火舌
      out.push(part('thigh', 'limb', [L('M14 -10 L19 -12 L26 -8 L22 -5 L29 -1 L23 2 L28 7 L21 8 L24 12 L14 10 Z', lin(s.c3, s.c2), K, 1.6), L(line([[14, -9.5], [14, 9.5]]), none, '#2A1A16', 1.2)], true));
      break;
    case 'frost': // 毛邊褲腳＋冰晶護膝
      out.push(part('shin', 'limb', [...[-6, -2, 2, 6].map((y) => L(circle(32, y, 3.4), solid(W), '#1D5A8A', 1.2)), L(P([[-3, 5], [2, 13], [6, 5], [2, 3]]), lin(W, s.c2), '#1D5A8A', 1.4)], true));
      break;
    case 'gold': // 拳擊短褲＋冠軍腰帶
      out.push(part('thigh', 'limb', [L('M-4 -11 L22 -12 L23 11 L-4 11 Z', lin(s.c3, '#8A1A18'), K, 2.2), L(line([[2, -11], [21, -11.5]]), none, GOLD[1], 2)], true));
      out.push(part('torso', 'over', [L(rrect(-1, -12, 8, 24, 2), solid('#7A1414'), K, 2), L(ellipse(3, 9, 7, 7.5), lin(GOLD[0], GOLD[1], GOLD[2]), K, 2), L(star(3, 9, 5, 4, 1.8), solid(s.c3)),
        L(circle(3, -5, 2.4), solid(GOLD[1]), K, 1)]));
      break;
    case 'shadow': // 小腿綁帶
      out.push(part('shin', 'limb', [...[6, 13, 20, 27].map((x) => L(P([[x, -7.5], [x + 4, -7.5], [x + 1, 7.5], [x - 3, 7.5]]), solid(s.c2, 0.85), K, 1))], true));
      break;
    case 'titan': // 大腿甲＋護膝
      out.push(part('thigh', 'limb', [L(rrect(6, -2, 20, 11, 3), lin('#C2CBD6', '#5A6676'), K, 1.8), ...glowLine(line([[10, 3], [22, 3]]), s.c2, 0.8)], true));
      out.push(part('shin', 'limb', [L('M-4 3 Q2 14 9 3 L7 -1 L-2 -1 Z', lin('#E6EBF0', '#8C98A8'), K, 1.8), L(circle(2.5, 5, 1.8), solid(s.c2))], true));
      break;
    case 'night': // 側邊口袋＋護膝
      out.push(part('thigh', 'limb', [L(rrect(12, -6, 12, 11, 2), solid('#141922'), K, 1.6), L(rrect(11, -6.5, 4, 12, 1), solid('#2A303A'), K, 1.2), L(circle(13, 3, 1), solid(s.c2))], true));
      out.push(part('shin', 'limb', [L(rrect(-3, 1, 11, 8, 3), solid('#3B4558'), K, 1.6), L(line([[0, 5], [5, 5]]), none, s.c2, 1.4)], true));
      break;
    case 'dawn': // 英雄外穿短褲
      out.push(part('thigh', 'limb', [L('M-4 -10.5 L8 -10 L10 0 L8 10 L-4 10.5 Z', lin(GOLD[0], s.c2), K, 2)], true));
      out.push(part('torso', 'over', [L(rrect(-1, -12, 6, 24, 2), solid(s.c3), K, 1.8), L(circle(2, 8, 3.6), lin(GOLD[0], s.c2), K, 1.4)]));
      break;
    case 'rune': // 腰甲片（垂片）＋護膝刺
      out.push(part('torso', 'over', [...[[-12, -3], [-4, 5], [4, 13]].map(([y0, y1]) => L(P([[4, y0], [4, y1], [-18, y1 + 1], [-18, y0 - 1]]), lin(s.c3, '#6B5A3A'), K, 1.8)), ...glowLine(line([[-6, 2], [-12, 2]]), s.c2, 0.9)]));
      out.push(part('shin', 'limb', [L(P([[-3, 3], [2, 15], [6, 3]]), lin(W, s.c3), K, 1.5)], true));
      break;
    case 'astral': // 星點＋尖褲腳
      out.push(part('shin', 'limb', [L(star(14, 2, 4, 3, 1), solid(s.c3)), L(star(24, -3, 4, 2.4, 0.8), solid(s.c2)), L(P([[30, -8], [37, -12], [36, -4], [38, 0], [36, 4], [37, 12], [30, 8]]), solid(s.c1), s.c2, 1.4)], true));
      break;
  }
  return out;
}

// ===================== 背部（nape：原點肩，x 往上，y 朝前；往後＝負 y、往下＝負 x） =====================
// 披風外形：上緣在肩，下緣在 x≈-86。edge(x0,y0,x1,y1) 回傳下緣路徑（從背側往身體側）
function capePath(edge) {
  return `M6 -2 Q-24 -20 -84 -32 ${edge} Q-40 -6 2 8 Z`;
}
const zig = (pts) => pts.map(([x, y]) => `L${f(x)} ${f(y)}`).join(' ');
function backArt(id) {
  const s = SERIES[id];
  switch (id) {
    case 'lava': { // 火焰披風：下緣火舌
      const edge = zig([[-96, -30], [-88, -26], [-102, -20], [-90, -16], [-100, -10], [-88, -8], [-94, -2], [-84, -4]]);
      return [part('nape', 'back', [L(capePath(edge), solid(s.c2, 0.8), null, 0, 3), L(capePath(edge), lin('#7A1C08', s.c2, s.c3), K, 2.6),
        L('M-10 -14 Q-40 -22 -70 -22', none, '#000000', 3), L(circle(4, 2, 4), solid(s.c3), K, 1.6)])];
    }
    case 'frost': { // 冰柱下緣＋冰晶
      const edge = zig([[-92, -30], [-86, -27], [-98, -23], [-86, -19], [-95, -14], [-85, -11], [-92, -6], [-84, -4]]);
      return [part('nape', 'back', [L(capePath(edge), lin(W, '#9ED8FF', s.c2), '#1D5A8A', 2.6), L(line([[-30, -14], [-44, -18]]), none, W, 1.6), L(line([[-37, -10], [-37, -22]]), none, W, 1.6),
        L('M-10 -16 Q-40 -22 -70 -24', none, '#1D5A8A', 2), ...[[-4, 4], [0, 2], [4, 0]].map(([dx, dy]) => L(circle(2 + dx, -2 + dy - 4, 4), solid(W), '#1D5A8A', 1.2))])];
    }
    case 'gold': { // 王者紅披風＋白貂毛邊＋金扣
      const edge = 'L-90 -30 Q-92 -16 -84 -4';
      const trim = 'M-84 -32 L-90 -30 Q-92 -16 -84 -4 L-78 -5 Q-84 -16 -80 -29 Z';
      return [part('nape', 'back', [L(capePath(edge), lin('#E0403A', s.c3, '#7A1414'), K, 2.6), L(trim, solid(W), K, 1.8),
        ...[[-85, -24], [-86, -16], [-83, -9]].map(([x, y]) => L(P([[x, y + 1.6], [x - 1, y], [x, y - 1.6], [x + 1, y]]), solid(K))),
        L('M-12 -16 Q-44 -24 -72 -26', none, '#000000', 3), L(ellipse(5, 2, 6, 5), lin(GOLD[0], GOLD[1]), K, 2), L(circle(5, 2, 2), solid(s.c3))])];
    }
    case 'shadow': { // 破布下緣
      const edge = zig([[-100, -34], [-90, -28], [-98, -22], [-86, -18], [-102, -12], [-88, -9], [-94, -3], [-84, -4]]);
      return [part('nape', 'back', [L(capePath(edge), solid(s.c2, 0.6), null, 0, 3), L(capePath(edge), lin('#2A1A44', '#120A1C'), K, 2.6), L('M-10 -14 Q-40 -22 -76 -24', none, s.c2, 1.4)])];
    }
    case 'night': { // 蝙蝠扇形下緣＋橘色內裡
      const edge = 'Q-80 -26 -92 -24 Q-82 -18 -90 -12 Q-80 -10 -88 -2 Q-82 -4 -84 -4';
      return [part('nape', 'back', [L(capePath(edge), lin('#232A36', '#0E1218'), K, 2.6), L('M2 6 Q-40 -4 -84 -4 Q-40 -8 2 3 Z', solid(s.c2), null, 0), L('M-10 -14 Q-40 -20 -74 -24', none, '#3B4558', 2), L(rrect(0, -2, 7, 7, 2), solid(s.c2), K, 1.4)])];
    }
    case 'dawn': { // 經典英雄長披風＋金邊
      const edge = 'Q-104 -34 -108 -20 Q-104 -8 -90 -4';
      const cape = `M6 -2 Q-24 -24 -92 -38 ${edge} Q-40 -6 2 8 Z`;
      return [part('nape', 'back', [L(cape, lin('#5A8CFF', s.c3, '#1A3F99'), K, 2.6), L('M-92 -38 Q-104 -34 -108 -20 Q-104 -8 -90 -4', none, s.c2, 3), L('M-14 -18 Q-50 -28 -84 -30', none, '#000000', 3), L(star(4, 1, 5, 5.5, 2.4), lin(GOLD[0], s.c2), K, 1.6)])];
    }
    case 'titan': { // 雙筒噴射背包
      return [part('nape', 'back', [...[-18, -26].map((y) => L(rrect(-36, y - 4, 26, 9, 3), lin('#C2CBD6', '#5A6676'), K, 2)),
        L(rrect(-30, -28, 20, 18, 3), solid('#5A6676'), K, 2),
        ...[-14, -22].map((y) => L(`M-36 ${y - 3} Q-58 ${y} -36 ${y + 3} Z`, solid(s.c2, 0.85), null, 0, 3)), ...[-14, -22].map((y) => L(`M-36 ${y - 2} Q-48 ${y} -36 ${y + 2} Z`, solid(W))),
        ...glowLine(line([[-16, -14], [-16, -22]]), s.c2, 1)])];
    }
    case 'rune': { // 背負巨劍
      return [part('nape', 'back', [L('M-70 -16 L10 -26 L18 -21 L10 -16 L-70 -8 Z', lin(W, '#9AA4AF'), K, 2.2), ...glowLine(line([[-62, -12], [4, -21]]), s.c2, 1),
        L(rrect(10, -34, 5, 26, 1.5), lin('#E6D2A2', s.c3), K, 1.8), L(rrect(15, -24, 12, 5, 2), solid('#5A3B22'), K, 1.6), L(circle(29, -21.5, 3.4), solid(s.c2), K, 1.4)])];
    }
    case 'neon': { // 能量背環（分段）
      const segs = [];
      for (let i = 0; i < 8; i++) {
        const a0 = i / 8 * 2 * Math.PI + 0.12, a1 = (i + 1) / 8 * 2 * Math.PI - 0.12;
        segs.push(...glowLine(`M${f(-8 + 26 * Math.cos(a0))} ${f(-12 + 26 * Math.sin(a0))} Q${f(-8 + 26 / Math.cos((a1 - a0) / 2) * Math.cos((a0 + a1) / 2))} ${f(-12 + 26 / Math.cos((a1 - a0) / 2) * Math.sin((a0 + a1) / 2))} ${f(-8 + 26 * Math.cos(a1))} ${f(-12 + 26 * Math.sin(a1))}`, i % 2 ? s.c3 : s.c2, 2));
      }
      return [part('nape', 'back', [...segs, L(circle(-8, -12, 4), solid(s.c2), K, 1.4)])];
    }
    case 'astral': { // 能量羽翼（左右兩層）
      const wing = (dx, op) => L(`M2 -6 Q30 -30 ${34 + dx} -60 Q16 -52 12 -44 Q20 -64 ${10 + dx} -76 Q-2 -58 0 -46 Q-6 -66 ${-16 - dx} -70 Q-14 -50 -10 -36 Q-20 -48 ${-34 - dx} -50 Q-24 -30 -14 -16 Z`, lin(W, s.c2, s.c3), s.c2, 1.4);
      return [part('nape', 'back', [{ ...wing(8, 0.5), fill: solid(s.c2, 0.5), blur: 3 }, { ...wing(8, 0.5), fill: lin(s.c3, s.c2) }, wing(0, 1)])];
    }
  }
  return [];
}

// ===================== 組合 =====================
const ids = Object.keys(SERIES);
const ART = {};
for (const id of ids) {
  if (id !== 'basic' || true) {
    ART[`${id}.bell`] = [part('grip', 'grip', bellArt(id), true)];
    ART[`${id}.feet`] = feetArt(id);
    ART[`${id}.hands`] = handsArt(id);
    ART[`${id}.top`] = topArt(id);
    ART[`${id}.bottom`] = bottomArt(id);
    const b = backArt(id);
    if (b.length) ART[`${id}.back`] = b;
  }
}
ART['default.bell'] = [part('grip', 'grip', defaultBell(), true)];

module.exports = { ART, SERIES };

// ---------- Swift ----------
const sw = (s) => JSON.stringify(s);
function swFill(fl) {
  if (fl[0] === 'solid') return `.solid(${sw(fl[1])}, ${fl[2]})`;
  if (fl[0] === 'lin') return `.linear([${fl[1].map(sw).join(', ')}])`;
  return `.radial([${fl[1].map(([h, a]) => `(${sw(h)}, ${a})`).join(', ')}])`;
}
function swLayer(l) {
  return `ArtLayer(${sw(l.d)}, ${swFill(l.fill)}${l.stroke ? `, stroke: ${sw(l.stroke)}, width: ${l.sw}` : ''}${l.blur ? `, blur: ${l.blur}` : ''})`;
}
let out = '// 自動產生，請勿手改：node scripts/art/gear.js\n// 每件裝備的造型圖層（局部座標說明見 scripts/art/gear.js 開頭）。\n\nenum GearArt {\n';
out += '    // swiftlint:disable:next cyclomatic_complexity function_body_length\n';
out += '    static func parts(_ id: String) -> [GearPart] {\n        switch id {\n';
out += Object.entries(ART).map(([id, ps]) => `        case ${sw(id)}:\n            return [\n` + ps.map((p) =>
  `                GearPart(anchor: .${p.anchor}, z: .${p.z}, far: ${p.far}, layers: [\n` + p.layers.map((l) => '                    ' + swLayer(l)).join(',\n') + '\n                ])').join(',\n') + '\n            ]').join('\n');
out += '\n        default:\n            return []\n        }\n    }\n}\n';
fs.writeFileSync(path.join(__dirname, '../../Workout/Character/GearArt.swift'), out);
