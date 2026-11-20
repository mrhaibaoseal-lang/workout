// 牌位動畫的預覽渲染器（瀏覽器 Canvas 2D）。由 badges.js 內嵌到預覽 HTML，資料在全域 BADGE。
// 公式和 App 的 Workout/Rank/BadgeMotion.swift、RankScene.swift 一一對應；改一邊要改另一邊。
/* global BADGE */
(() => {
  // ---------- 共用數學 ----------
  const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
  const fract = (x) => x - Math.floor(x);
  const rnd = (i, salt = 0) => fract(Math.sin(i * 12.9898 + salt * 78.233) * 43758.5453);
  const easeOutCubic = (x) => 1 - Math.pow(1 - x, 3);
  const easeInCubic = (x) => x * x * x;
  const easeOutBack = (x) => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };
  const easeOutBounce = (x) => {
    const n = 7.5625, d = 2.75;
    if (x < 1 / d) return n * x * x;
    if (x < 2 / d) return n * (x -= 1.5 / d) * x + 0.75;
    if (x < 2.5 / d) return n * (x -= 2.25 / d) * x + 0.9375;
    return n * (x -= 2.625 / d) * x + 0.984375;
  };
  const smooth = (x) => { x = clamp(x); return x * x * (3 - 2 * x); };
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  // 用力的節奏：快速衝到 1、停一下、慢慢放掉
  const env = (t, p) => {
    const u = ((t % p) + p) % p;
    if (u < 0.12) return easeOutCubic(u / 0.12);
    if (u < 0.32) return 1;
    if (u < 0.8) return 1 - smooth((u - 0.32) / 0.48);
    return 0;
  };
  const TAU = Math.PI * 2;
  const hexA = (h, a) => {
    const n = parseInt(h.slice(1), 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
  };
  const mix = (h1, h2, t) => {
    const a = parseInt(h1.slice(1), 16), b = parseInt(h2.slice(1), 16);
    const c = (s) => Math.round(((a >> s) & 255) * (1 - t) + ((b >> s) & 255) * t);
    return '#' + ((1 << 24) + (c(16) << 16) + (c(8) << 8) + c(0)).toString(16).slice(1);
  };

  // ---------- 圖層 ----------
  const pathCache = new Map();
  const P2 = (d) => { let p = pathCache.get(d); if (!p) { p = new Path2D(d); pathCache.set(d, p); } return p; };
  const boxCache = new Map();
  const bbox = (d) => {
    let b = boxCache.get(d);
    if (b) return b;
    const n = d.match(/-?\d+(\.\d+)?/g).map(Number);
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (let i = 0; i + 1 < n.length; i += 2) { x0 = Math.min(x0, n[i]); x1 = Math.max(x1, n[i]); y0 = Math.min(y0, n[i + 1]); y1 = Math.max(y1, n[i + 1]); }
    b = { x: x0, y: y0, w: x1 - x0, h: y1 - y0, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2 };
    boxCache.set(d, b);
    return b;
  };
  function paint(ctx, l, alpha, white = 0) {
    const p = P2(l.d), b = bbox(l.d), fl = l.fill;
    if (alpha > 0.001) {
      ctx.globalAlpha = alpha;
      let fill = null;
      if (fl[0] === 'solid') { if (fl[2] > 0) fill = hexA(fl[1], fl[2]); }
      else if (fl[0] === 'lin') {
        const g = ctx.createLinearGradient(b.cx, b.y, b.cx, b.y + b.h);
        const n = Math.max(1, fl[1].length - 1);
        fl[1].forEach((h, i) => g.addColorStop(i / n, h));
        fill = g;
      } else {
        const g = ctx.createRadialGradient(b.cx, b.cy, 0, b.cx, b.cy, Math.max(b.w, b.h) / 2);
        const n = Math.max(1, fl[1].length - 1);
        fl[1].forEach(([h, a], i) => g.addColorStop(i / n, hexA(h, a)));
        fill = g;
      }
      if (fill) { ctx.fillStyle = fill; ctx.fill(p); }
      if (l.stroke && l.sw > 0) {
        ctx.strokeStyle = l.stroke; ctx.lineWidth = l.sw; ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.stroke(p);
      }
    }
    // 白光：整枚獎章變成白色剪影（光暈、半透明層不算，免得變成白色圓盤）
    if (white > 0.001 && fl[0] !== 'rad') {
      ctx.globalAlpha = Math.min(1, white);
      ctx.fillStyle = '#FFFFFF';
      if (fl[0] === 'lin' || fl[2] >= 0.3) ctx.fill(p);
      if (l.stroke && l.sw > 0) { ctx.strokeStyle = '#FFFFFF'; ctx.stroke(p); }
    }
    ctx.globalAlpha = 1;
  }

  // ---------- 待機動作 ----------
  // 回傳 {tx, ty, rot(弧度), sx, sy, alpha}，繞 (px, py)
  function motion(l, ops, t) {
    const m = { tx: 0, ty: 0, rot: 0, sx: 1, sy: 1, alpha: 1 };
    if (!l.part) return m;
    const sg = l.m ? -1 : 1, i = l.i || 0;
    for (const o of ops) {
      if (o.part !== l.part) continue;
      const ph = t + i * o.st, w = Math.sin(TAU * ph / o.p);
      switch (o.kind) {
        case 0: m.rot += o.a * t * Math.PI / 180; break;
        case 1: m.rot += sg * o.a * w * Math.PI / 180; break;
        case 2: m.sx *= 1 + o.a * w; m.sy *= 1 + o.a * w; break;
        case 3: m.ty += o.a * (0.5 + 0.5 * w); break;
        case 4: { const v = 0.5 + 0.5 * w; const s = 0.4 + 0.8 * v * v; m.sx *= s; m.sy *= s; m.alpha *= 0.3 + 0.7 * v; break; }
        case 5: { const s = 1 + o.a * env(ph, o.p); m.sx *= s; m.sy *= s; break; }
        case 6: m.sy *= 1 + o.a * (0.6 * Math.sin(t * 11 + i * o.st * 3) + 0.4 * Math.sin(t * 17.3 + i * 2.1));
          m.rot += 0.05 * Math.sin(t * 9 + i); break;
        case 7: m.alpha *= 0.15 + 0.85 * env(ph, o.p); break;
        case 8: m.rot += sg * o.a * env(ph, o.p) * Math.PI / 180; break;
        case 9: m.tx += sg * o.a * env(ph, o.p) * Math.sin(t * 70); break;
        case 10: m.alpha *= 1 - o.a + o.a * (0.5 + 0.5 * w); break;
        case 11: { const dx = l.px - 60, dy = l.py - 58, n = Math.hypot(dx, dy) || 1, v = o.a * (0.5 + 0.5 * w); m.tx += dx / n * v; m.ty += dy / n * v; break; }
      }
    }
    return m;
  }

  // 部位分組：轉場時誰先出現。0 底座、1 手臂與核心、2 配件、3 光暈星光、4 皇冠
  const GROUP = { 0: 0, 10: 1, 11: 1, 13: 1, 1: 3, 12: 3, 14: 3, 8: 4 };
  const group = (l) => (l.part === undefined || l.part === 0 ? 0 : GROUP[l.part] ?? 2);
  const WINDOW = [[0, 0.35], [0.25, 0.6], [0.35, 0.8], [0.6, 0.95], [0.7, 1]];

  // 一個圖層在轉場中的位移：{tx, ty, rot, s, alpha}，rot/s 繞圖層中心
  function transit(l, j, fx) {
    const r = { tx: 0, ty: 0, rot: 0, s: 1, alpha: fx.alpha ?? 1 };
    const g = group(l), b = bbox(l.d);
    let dx = b.cx - 60, dy = b.cy - 58, n = Math.hypot(dx, dy);
    if (n < 6) { const a = rnd(j, 3) * TAU; dx = Math.cos(a); dy = Math.sin(a); n = 1; }
    dx /= n; dy /= n;
    if (fx.assemble < 1 && !(fx.keepCore && g <= 1)) {
      const [w0, w1] = WINDOW[g];
      const st = g === 2 ? (j % 7) / 7 * 0.12 : 0;
      const lp = seg(fx.assemble, w0 + st, Math.min(1, w1 + st));
      if (g === 0) { r.s *= Math.max(0, easeOutBack(lp)); r.alpha *= clamp(lp * 3); r.cx = 60; r.cy = 58; }
      else if (g === 1) { r.s *= 1 + 1.2 * (1 - easeOutCubic(lp)); r.alpha *= clamp(lp * 2); }
      else if (g === 4) { r.ty += -(fx.crownDrop || 110) * (1 - easeOutBounce(lp)); r.alpha *= clamp(lp * 4); }
      else {
        const e = easeOutBack(lp), d = 90 + rnd(j, 5) * 40;
        r.tx += dx * d * (1 - e); r.ty += dy * d * (1 - e);
        r.rot += (rnd(j, 7) - 0.5) * 2.1 * (1 - e); r.alpha *= clamp(lp * 2);
      }
    }
    if (fx.explode > 0) {
      const e = fx.explode, d = 150 * easeOutCubic(e) * (0.6 + 0.8 * rnd(j, 11));
      r.tx += dx * d; r.ty += dy * d + 80 * e * e;
      r.rot += (rnd(j, 13) - 0.5) * 9.4 * e; r.s *= 1 - 0.3 * e; r.alpha *= 1 - Math.pow(e, 1.5);
    }
    if (fx.drop > 0 && g >= 2) {
      const lp = clamp(fx.drop * 1.6 - rnd(j, 17) * 0.6);
      r.ty += 140 * lp * lp; r.rot += (rnd(j, 19) - 0.5) * 1.05 * lp; r.alpha *= 1 - lp;
    }
    return r;
  }

  // ---------- 粒子 ----------
  function star4(ctx, x, y, r, col, a) {
    ctx.globalAlpha = a; ctx.fillStyle = col; ctx.beginPath();
    for (let k = 0; k < 8; k++) { const rr = k % 2 ? r * 0.22 : r, an = k * Math.PI / 4 - Math.PI / 2; ctx.lineTo(x + rr * Math.cos(an), y + rr * Math.sin(an)); }
    ctx.closePath(); ctx.fill(); ctx.globalAlpha = 1;
  }
  // 發光點：實心點＋淡淡的光圈，用相加混色讓它亮起來
  function dot(ctx, x, y, r, col, a) {
    if (a <= 0.01) return;
    const op = ctx.globalCompositeOperation; ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = a; ctx.fillStyle = col; ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, TAU); ctx.fill();
    ctx.globalAlpha = a * 0.25; ctx.beginPath(); ctx.arc(x, y, r * 2.4, 0, TAU); ctx.fill(); ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = op;
  }
  // 旋轉的十字星（鏡頭光芒用）
  function star4r(ctx, x, y, r, rot, col, a) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot); star4(ctx, 0, 0, r, col, a); ctx.restore();
  }
  // 斜軌道橢圓上的點：r、h 半軸，tilt 傾斜（弧度）
  const orbitPt = (r, h, tilt, a) => {
    const ex = r * Math.cos(a), ey = h * Math.sin(a);
    return [60 + ex * Math.cos(tilt) - ey * Math.sin(tilt), 58 + ex * Math.sin(tilt) + ey * Math.cos(tilt)];
  };
  // 進階粒子（kind 8 以上），每一種自己跑迴圈。front：畫在獎章前面（true）或後面（false）
  function fancy(ctx, q, si, t, front, fade) {
    const op = ctx.globalCompositeOperation;
    ctx.globalCompositeOperation = 'lighter';
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    switch (q.k) {
      case 8: { // burst：每次用力，從中心噴出光條
        if (!front) break;
        const u = ((t % q.p) + q.p) % q.p;
        if (u > 0.9) break;
        const e = easeOutCubic(Math.min(1, u / 0.6)), a = (1 - u / 0.9) * fade;
        for (let j = 0; j < q.n; j++) {
          const an = rnd(j, si + 81) * TAU, d = 28 + (q.r - 28) * (0.4 + 0.6 * rnd(j, si + 82)) * e;   // 從獎章邊緣往外噴，不蓋住正面
          const x = 60 + d * Math.cos(an), y = 56 + d * Math.sin(an) + 10 * u * u;
          const len = 3 + 7 * (1 - u);
          ctx.globalAlpha = a; ctx.strokeStyle = mix(q.c, q.c2, u / 0.9); ctx.lineWidth = q.s;
          ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - len * Math.cos(an), y - len * Math.sin(an)); ctx.stroke();
          dot(ctx, x, y, q.s * 0.45, '#FFFFFF', a);
        }
        break;
      }
      case 9: { // comet：斜軌道上的彗星，拖一條漸淡的尾巴
        for (let j = 0; j < q.n; j++) {
          const tilt = j / q.n * Math.PI + 0.35, an = TAU * (t / q.p + j * 0.37);
          for (let k = 15; k >= 0; k--) {
            const a = an - k * 0.06;
            if ((Math.sin(a) > 0) !== front) continue;
            const [x, y] = orbitPt(q.r, q.h, tilt, a), f = 1 - k / 16;
            dot(ctx, x, y, q.s * (0.2 + 0.5 * f), k === 0 ? '#FFFFFF' : mix(q.c, q.c2, k / 16), Math.pow(f, 1.5) * fade);
          }
        }
        break;
      }
      case 10: { // halo：旋轉的符文環（虛線橢圓），後半圈較暗
        const tilt = q.y * Math.PI / 180, off = TAU * t / q.p, seg = TAU / q.n;
        ctx.strokeStyle = q.c;
        if (!front) {
          ctx.globalAlpha = 0.12 * fade; ctx.lineWidth = q.s * 0.6; ctx.beginPath();
          for (let i = 0; i <= 48; i++) { const [x, y] = orbitPt(q.r, q.h, tilt, i / 48 * TAU); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
          ctx.stroke();
        }
        for (let i = 0; i < q.n; i++) {
          const a0 = off + i * seg, mid = a0 + seg * 0.3;
          if ((Math.sin(mid) > 0) !== front) continue;
          const len = i % 3 === 0 ? 0.75 : 0.4;
          ctx.globalAlpha = fade * (front ? 0.95 : 0.45); ctx.lineWidth = q.s; ctx.beginPath();
          for (let k = 0; k <= 4; k++) { const [x, y] = orbitPt(q.r, q.h, tilt, a0 + seg * len * k / 4); k ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
          ctx.stroke();
          if (i % 3 === 0) { const [x, y] = orbitPt(q.r, q.h, tilt, a0 + seg * 0.9); dot(ctx, x, y, q.s * 0.9, q.c, fade * (front ? 1 : 0.5)); }
        }
        break;
      }
      case 11: { // pulse：用力時從中心擴散的光環
        if (front) break;
        for (let j = 0; j < q.n; j++) {
          const u = ((((t % q.p) + q.p) % q.p) - j * 0.18) / 1.1;
          if (u <= 0 || u >= 1) continue;
          ctx.globalAlpha = (1 - u) * (1 - u) * fade * 0.9; ctx.strokeStyle = q.c; ctx.lineWidth = q.s * (1 - u) + 0.3;
          ctx.beginPath(); ctx.arc(60, 58, q.r * easeOutCubic(u), 0, TAU); ctx.stroke();
        }
        break;
      }
      case 12: { // arc：繞著獎章跳的閃電，每 0.07 秒換一次形狀
        if (!front) break;
        for (let j = 0; j < q.n; j++) {
          const w = fract(t / q.p + rnd(j, si + 91));
          if (w > 0.3) continue;
          const a = (1 - w / 0.3) * fade, seed = Math.floor(t / 0.07) + j * 131;
          const a0 = rnd(seed, si + 92) * TAU, span = (0.7 + 0.9 * rnd(seed, si + 93)) * (rnd(seed, si + 94) > 0.5 ? 1 : -1);
          const pts = [];
          for (let k = 0; k <= 7; k++) {
            const an = a0 + span * k / 7, rr = q.r * (k === 0 || k === 7 ? 1 : 0.82 + 0.36 * rnd(seed * 8 + k, si + 95));
            pts.push([60 + rr * Math.cos(an), 58 + rr * Math.sin(an)]);
          }
          for (const [wd, col, al] of [[3.2, q.c, 0.35], [q.s, '#FFFFFF', 1]]) {
            ctx.globalAlpha = a * al; ctx.strokeStyle = col; ctx.lineWidth = wd; ctx.beginPath();
            pts.forEach(([x, y], k) => (k ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.stroke();
          }
        }
        break;
      }
      case 13: { // flare：鏡頭光芒，慢慢轉、一明一暗
        if (!front) break;
        for (let j = 0; j < q.n; j++) {
          const x = j ? 60 + q.r : 60 - q.r, y = j ? 58 + q.h * 0.9 : 58 - q.h;
          const pl = 0.65 + 0.35 * Math.sin(TAU * t / q.p + j * 2), sz = q.s * pl;
          dot(ctx, x, y, sz * 0.22, q.c, 0.7 * fade);
          star4r(ctx, x, y, sz, t * 0.4 + j, q.c, 0.9 * fade * pl);
          star4r(ctx, x, y, sz * 0.5, t * 0.4 + j + Math.PI / 4, q.c, 0.7 * fade * pl);
        }
        break;
      }
      case 14: { // flame：往上竄的火舌
        if (!front) break;
        for (let j = 0; j < q.n; j++) {
          const r1 = rnd(j, si + 1), r2 = rnd(j, si + 2), r3 = rnd(j, si + 3);
          const u = fract(t / (q.p * (0.7 + 0.6 * r3)) + r1);
          const x = 60 + (r2 - 0.5) * q.r + Math.sin(u * 5 + r3 * 6) * 4, y = q.y - u * q.h, s2 = q.s * (1 - u * 0.7);
          ctx.globalAlpha = Math.sin(Math.PI * u) * fade * 0.85; ctx.fillStyle = mix(q.c, q.c2, u);
          ctx.beginPath(); ctx.moveTo(x, y - 2.2 * s2); ctx.quadraticCurveTo(x + s2, y - 0.4 * s2, x, y + s2);
          ctx.quadraticCurveTo(x - s2, y - 0.4 * s2, x, y - 2.2 * s2); ctx.fill();
        }
        break;
      }
      case 15: { // beam：背後一道道光柱，輪流亮起
        if (front) break;
        for (let j = 0; j < q.n; j++) {
          const r1 = rnd(j, si + 1), r2 = rnd(j, si + 2), r3 = rnd(j, si + 3);
          const x = 60 + (r1 - 0.5) * q.r, w = q.s * (0.6 + 0.6 * r2);
          const a = Math.pow(0.5 + 0.5 * Math.sin(TAU * (t / q.p + r3)), 2) * 0.35 * fade;
          const top = 58 - q.h / 2, g = ctx.createLinearGradient(0, top, 0, top + q.h);
          g.addColorStop(0, hexA(q.c, 0)); g.addColorStop(0.5, hexA(q.c, a)); g.addColorStop(1, hexA(q.c, 0));
          ctx.globalAlpha = 1; ctx.fillStyle = g; ctx.fillRect(x - w / 2, top, w, q.h);
        }
        break;
      }
    }
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = op;
  }
  function particles(ctx, specs, t, front, fade = 1) {
    specs.forEach((q, si) => {
      if (q.k >= 8) { fancy(ctx, q, si * 10, t, front, fade); return; }
      for (let j = 0; j < q.n; j++) {
        const r1 = rnd(j, si * 10 + 1), r2 = rnd(j, si * 10 + 2), r3 = rnd(j, si * 10 + 3);
        switch (q.k) {
          case 0: case 6: case 4: { // mote / ember / fall
            if (!front) break;
            const u = fract(t / (q.p * (0.7 + 0.6 * r3)) + r1);
            const x = 60 + (r2 - 0.5) * q.r + Math.sin(u * 6 + r3 * 6) * 5;
            const y = q.k === 4 ? -5 + u * q.h : q.y - u * q.h;
            const a = Math.sin(Math.PI * u) * fade;
            const col = q.k === 6 ? mix(q.c, q.c2, u) : q.c;
            dot(ctx, x, y, q.s * (q.k === 6 ? 1 - u * 0.6 : 1), col, a * (q.k === 6 ? 0.6 + 0.4 * Math.sin(t * 20 + j) : 1));
            break;
          }
          case 1: case 7: { // orbit / crystal
            const an = TAU * (t / q.p + j / q.n);
            const isFront = Math.sin(an) > 0;
            if (isFront !== front) break;
            const x = 60 + q.r * Math.cos(an), y = 58 + q.h * Math.sin(an) - 6 * Math.cos(an);
            const a = (0.45 + 0.55 * (0.5 + 0.5 * Math.sin(an))) * fade;
            if (q.k === 1) dot(ctx, x, y, q.s, q.c, a);
            else {
              ctx.save(); ctx.translate(x, y); ctx.rotate(t * 2 + j); ctx.globalAlpha = a; ctx.fillStyle = q.c;
              ctx.beginPath(); ctx.moveTo(0, -q.s); ctx.lineTo(q.s * 0.6, 0); ctx.lineTo(0, q.s); ctx.lineTo(-q.s * 0.6, 0); ctx.closePath(); ctx.fill();
              ctx.globalAlpha = 1; ctx.restore();
            }
            break;
          }
          case 2: { // glint
            if (!front) break;
            const v = t / q.p + r1, cyc = Math.floor(v), u = fract(v);
            const an = rnd(cyc * 7 + j, si + 21) * TAU, rr = q.r * (0.55 + 0.45 * rnd(cyc * 7 + j, si + 22));
            const s = Math.pow(Math.sin(Math.PI * clamp(u * 2.2)), 2);
            if (s > 0.01) star4(ctx, 60 + rr * Math.cos(an), 58 + rr * Math.sin(an), q.s * s, q.c, s * fade);
            break;
          }
          case 3: { // spark
            if (!front) break;
            const u = fract(t / q.p + r1);
            if (u > 0.55) break;
            const tt = u * q.p, vx = (r2 - 0.5) * 70, vy = -(30 + r3 * 45);
            const x = 60 + (r2 - 0.5) * q.r + vx * tt, y = q.y + vy * tt + 70 * tt * tt;
            const a = (1 - u / 0.55) * fade;
            ctx.globalAlpha = a; ctx.strokeStyle = mix(q.c, q.c2, u / 0.55); ctx.lineWidth = q.s; ctx.lineCap = 'round';
            ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - vx * 0.05, y - (vy + 140 * tt) * 0.05); ctx.stroke(); ctx.globalAlpha = 1;
            break;
          }
          case 5: { // spiral
            if (!front) break;
            const u = fract(t / q.p + r1), an = r2 * TAU + u * TAU * 1.5;
            const rr = q.r * (1 - u * 0.6);
            dot(ctx, 60 + rr * Math.cos(an), q.y - u * q.h, q.s, q.c, Math.sin(Math.PI * u) * fade * (0.5 + 0.5 * Math.sin(an)));
            break;
          }
        }
      }
    });
  }

  // ---------- 一枚獎章 ----------
  // fx: {t 待機時間, idle, particles(0…1), sheen, assemble, keepCore, explode, drop, flash, numeral, numFlip:{from,to,p}, crownDrop}
  function drawBadge(ctx, tier, division, fx) {
    const looks = BADGE.tiers[tier];
    const lv = division ? 3 - division : looks.length - 1;
    const layers = looks[Math.max(0, Math.min(looks.length - 1, lv))];
    const ops = fx.idle ? BADGE.motion[tier] : [];
    const t = fx.t || 0;
    const pf = fx.particles ?? 0;
    const full = { assemble: 1, explode: 0, drop: 0, ...fx };
    if (pf > 0) particles(ctx, BADGE.particles[tier], t, false, pf);
    const placed = [];
    layers.forEach((l, j) => {
      const m = motion(l, ops, t), r = transit(l, j, full);
      if (r.alpha * m.alpha <= 0.001 && !(full.flash > 0)) return;
      const b = bbox(l.d);
      const cx = r.cx ?? b.cx, cy = r.cy ?? b.cy;
      ctx.save();
      ctx.translate(r.tx, r.ty);
      if (r.rot || r.s !== 1) { ctx.translate(cx, cy); ctx.rotate(r.rot); ctx.scale(r.s, r.s); ctx.translate(-cx, -cy); }
      ctx.translate(m.tx, m.ty);
      if (l.part) { ctx.translate(l.px, l.py); ctx.rotate(m.rot); ctx.scale(m.sx, m.sy); ctx.translate(-l.px, -l.py); }
      paint(ctx, l, r.alpha * m.alpha, (full.flash || 0) * r.alpha);
      if (l.clip) placed.push({ l, tr: ctx.getTransform() });
      ctx.restore();
    });
    // 反光掃過：只畫在獎章輪廓裡
    if (fx.sheen !== undefined && fx.sheen !== null && placed.length) {
      const [per, str] = BADGE.sheen[tier];
      const u = fx.sheen === true ? (t % per) / (per * 0.45) : fx.sheen;
      if (u >= 0 && u <= 1) {
        ctx.save();
        const base = ctx.getTransform();
        const clip = new Path2D();
        for (const q of placed) clip.addPath(P2(q.l.d), base.inverse().multiply(q.tr));
        ctx.clip(clip);
        const x = -30 + 180 * u;
        ctx.translate(x, 58); ctx.rotate(0.35);
        const g = ctx.createLinearGradient(-14, 0, 14, 0);
        g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, `rgba(255,255,255,${str})`); g.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.fillStyle = g; ctx.globalCompositeOperation = 'lighter'; ctx.fillRect(-14, -90, 28, 180);
        ctx.restore();
      }
    }
    if (pf > 0) particles(ctx, BADGE.particles[tier], t, true, pf);
    // 緞帶＋羅馬數字（畫在粒子上面，小段永遠看得清楚）
    if (division) {
      const r = transit({ d: 'M38 96 L82 112', part: 10 }, 99, full);
      ctx.save();
      ctx.translate(60 + r.tx, 104 + r.ty); ctx.rotate(r.rot); ctx.scale(r.s, r.s); ctx.translate(-60, -104);
      BADGE.ribbons[tier].forEach((l) => paint(ctx, l, r.alpha, full.flash || 0));
      const nf = fx.numFlip;
      let n = division, sy = 1, wh = 0;
      if (nf && nf.p < 1) {
        const p = clamp(nf.p);
        if (p < 0.5) { n = nf.from; sy = 1 - p * 2; } else { n = nf.to; sy = p * 2 - 1; }
        wh = 1 - Math.abs(p - 0.5) * 2;
      }
      ctx.translate(60, 104); ctx.scale(1, Math.max(0.01, sy)); ctx.translate(-60, -104);
      BADGE.numerals[n].forEach((l) => paint(ctx, l, r.alpha, Math.max(wh, full.flash || 0)));
      ctx.restore();
    }
  }

  // ---------- 晉級／掉段場景 ----------
  // kind: 'div' 升小段、'tier' 跨階（大師、王者有額外特效）、'down' 掉段
  const SCENE = {
    div: { boom: 1.4, impact: 1.4, title: 1.6, end: 2.8 },
    tier: { boom: 2.0, impact: 3.4, title: 3.5, end: 4.8 },
    down: { boom: 1.9, impact: 1.9, title: 2.3, end: 3.4 },
  };
  function sceneKind(from, to) {
    if (to.idx < from.idx) return 'down';
    return to.tier === from.tier ? 'div' : 'tier';
  }
  function rays(ctx, cx, cy, R, n, ang, col, a) {
    for (let i = 0; i < n; i++) {
      const a0 = ang + i * TAU / n, h = TAU / n * 0.28;
      const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R);
      g.addColorStop(0, hexA(col, a)); g.addColorStop(1, hexA(col, 0));
      ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(cx, cy);
      ctx.lineTo(cx + R * Math.cos(a0 - h), cy + R * Math.sin(a0 - h)); ctx.lineTo(cx + R * Math.cos(a0 + h), cy + R * Math.sin(a0 + h));
      ctx.closePath(); ctx.fill();
    }
  }
  function ring(ctx, cx, cy, q, maxR, col) {
    if (q <= 0 || q >= 1) return;
    ctx.globalAlpha = 1 - q; ctx.strokeStyle = col; ctx.lineWidth = 16 * (1 - q) + 1;
    ctx.beginPath(); ctx.arc(cx, cy, easeOutCubic(q) * maxR, 0, TAU); ctx.stroke(); ctx.globalAlpha = 1;
  }
  function confetti(ctx, cx, cy, tau, n, cols, H) {
    if (tau <= 0) return;
    for (let j = 0; j < n; j++) {
      const r1 = rnd(j, 31), r2 = rnd(j, 32), r3 = rnd(j, 33), r4 = rnd(j, 34), r5 = rnd(j, 35);
      const vx = (r1 - 0.5) * 900, vy = -(350 + r2 * 650);
      const k = (1 - Math.exp(-2.5 * tau)) / 2.5;
      const x = cx + vx * k + Math.sin(tau * 3 + r3 * 6) * 18 * tau;
      const y = cy + vy * k + 300 * tau * tau / (1 + tau);
      if (y > H + 20) continue;
      const a = clamp(3.2 - tau);
      ctx.save(); ctx.translate(x, y); ctx.rotate(r3 * TAU + tau * (r4 - 0.5) * 16);
      ctx.scale(Math.abs(Math.cos(tau * (5 + r5 * 6))) + 0.15, 1);
      ctx.globalAlpha = a; ctx.fillStyle = cols[j % cols.length];
      if (j % 3 === 0) { ctx.beginPath(); ctx.arc(0, 0, 4, 0, TAU); ctx.fill(); } else ctx.fillRect(-4, -7, 8, 14);
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }
  function converge(ctx, cx, cy, t, R, col, n, a) {
    for (let j = 0; j < n; j++) {
      const an = rnd(j, 41) * TAU, u = fract(t / 0.7 + rnd(j, 42));
      const r = R * (1 - easeInCubic(u)) + 10, r2 = r + 26 * (1 - u) + 6;
      ctx.globalAlpha = u * a; ctx.strokeStyle = col; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(cx + r * Math.cos(an), cy + r * Math.sin(an)); ctx.lineTo(cx + r2 * Math.cos(an), cy + r2 * Math.sin(an)); ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }
  function screenEmbers(ctx, W, H, t, n, a) {
    for (let j = 0; j < n; j++) {
      const per = 2 + rnd(j, 52) * 2, u = fract(t / per + rnd(j, 53));
      const x = rnd(j, 51) * W + Math.sin(t * 2 + j) * 20, y = H + 10 - u * (H * 1.1);
      dot(ctx, x, y, 1.5 + rnd(j, 54) * 2.5, mix('#FFE08A', '#FF3A1A', u), Math.sin(Math.PI * u) * a);
    }
  }
  function vortex(ctx, cx, cy, t, n, R, col, a) {
    for (let j = 0; j < n; j++) {
      const u = fract(t / 2.6 + rnd(j, 61)), an = rnd(j, 62) * TAU + u * TAU * 1.2 + t * 0.3;
      const r = R * (1 - u);
      dot(ctx, cx + r * Math.cos(an), cy + r * Math.sin(an) * 0.8, 1.2 + 2 * (1 - u), col, Math.sin(Math.PI * u) * a);
    }
  }
  function dust(ctx, W, H, t, n, a) {
    for (let j = 0; j < n; j++) {
      const u = fract(t / (3 + rnd(j, 72) * 2) + rnd(j, 73));
      dot(ctx, rnd(j, 71) * W, -10 + u * (H + 20), 1 + rnd(j, 74) * 1.5, '#8A94A3', Math.sin(Math.PI * u) * a * 0.6);
    }
  }

  // 場景狀態：所有東西都是時間 t 的函式（App 版同樣這樣算，可以隨時跳到結尾）
  function scene(ctx, W, H, from, to, t) {
    const kind = sceneKind(from, to), S = SCENE[kind];
    const P = BADGE.pal[to.tier], OP = BADGE.pal[from.tier];
    const cx = W / 2, cy = H * 0.4, sz = Math.min(W * 0.62, 260), k = sz / 120;
    const master = kind === 'tier' && to.tier === 6, champ = kind === 'tier' && to.tier === 7;
    ctx.fillStyle = '#0E1218'; ctx.fillRect(0, 0, W, H);
    // 背景
    const after = seg(t, S.boom, S.boom + 0.6);
    const bgCol = kind === 'down' ? '#3A4250' : P[2];
    let g = ctx.createRadialGradient(cx, cy, 10, cx, cy, Math.max(W, H) * 0.8);
    g.addColorStop(0, hexA(bgCol, kind === 'down' ? 0.35 : 0.25 + 0.45 * after)); g.addColorStop(1, hexA(bgCol, 0));
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    if (champ) { g = ctx.createLinearGradient(0, H, 0, H * 0.3); g.addColorStop(0, hexA('#FF4A1F', 0.45 * after)); g.addColorStop(1, hexA('#FF4A1F', 0)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
    if (kind !== 'down') {
      // 光柱＋旋轉光芒
      const pa = kind === 'div' ? 0.6 * after : after;
      g = ctx.createLinearGradient(cx - sz * 0.45, 0, cx + sz * 0.45, 0);
      g.addColorStop(0, hexA(P[0], 0)); g.addColorStop(0.5, hexA(P[0], 0.28 * pa)); g.addColorStop(1, hexA(P[0], 0));
      ctx.fillStyle = g; ctx.fillRect(cx - sz * 0.45, 0, sz * 0.9, H);
      rays(ctx, cx, cy, Math.max(W, H), master || champ ? 18 : 14, t * 0.2, P[0], 0.22 * pa);
      if (master) vortex(ctx, cx, cy, t, 60, Math.max(W, H) * 0.6, '#D9A6FF', 0.4 + 0.6 * seg(t, 0.4, S.boom));
      if (champ) screenEmbers(ctx, W, H, t, 50, 0.3 + 0.7 * seg(t, 0.5, S.boom));
      // 蓄力：光點往中心收
      const cg = seg(t, 0.4, S.boom);
      if (t < S.boom) converge(ctx, cx, cy, t, sz * 1.2, P[0], 40, cg);
    } else dust(ctx, W, H, t, 30, seg(t, 0.6, 1.4));
    // 背後光暈
    g = ctx.createRadialGradient(cx, cy, 0, cx, cy, sz * 0.75);
    const glow = kind === 'down' ? 0.2 : 0.2 + 0.5 * seg(t, 0.4, S.boom) * (t < S.boom ? 1 : 0) + 0.45 * after;
    g.addColorStop(0, hexA(kind === 'down' ? '#9AA5B1' : P[0], glow)); g.addColorStop(1, hexA(P[0], 0));
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);

    // 獎章
    let shake = 0, punch = 1;
    const fx = { idle: false, particles: 0 };
    let tier = from.tier, div = from.div, gray = 0;
    if (kind === 'down') {
      if (t < S.boom) {
        Object.assign(fx, { assemble: seg(t, 0, 0.5), drop: seg(t, 0.7, S.boom), t: 0 });
        shake = 1.5 * Math.max(0, 1 - Math.abs(t - 1.1) * 1.4); gray = seg(t, 0.7, S.boom) * 0.85;
      } else {
        tier = to.tier; div = to.div;
        // 掉段：新獎章安靜地淡入，不飛入、不灑彩帶
        Object.assign(fx, { alpha: seg(t, S.boom, S.boom + 0.5), idle: true, t: t - S.boom, particles: 0.5 * seg(t, S.boom + 0.6, S.boom + 1.2) });
        punch = 0.9 + 0.1 * easeOutCubic(seg(t, S.boom, S.boom + 0.6));
        gray = 0.6 * (1 - seg(t, 2.2, 2.9));
        if (from.div && to.div && from.tier === to.tier) fx.numFlip = { from: from.div, to: to.div, p: seg(t, 2.0, 2.4) };
      }
    } else if (t < S.boom) {
      const c = seg(t, 0.4, S.boom);
      Object.assign(fx, { assemble: seg(t, 0, 0.45), flash: 0.85 * Math.pow(c, 3), t: 0 });
      shake = (kind === 'div' ? 2 : 3.5) * c * c;
    } else {
      tier = to.tier; div = to.div;
      if (kind === 'tier') {
        const e = seg(t, S.boom, S.boom + 0.9);
        if (e < 1) {
          ctx.save(); ctx.translate(cx - 60 * k, cy - 58 * k); ctx.scale(k, k);
          drawBadge(ctx, from.tier, from.div, { explode: e, flash: 0.9 * (1 - e), t: 0 });
          ctx.restore();
        }
        Object.assign(fx, { assemble: seg(t, S.boom + 0.2, S.impact), flash: 0, crownDrop: master || champ ? 260 : 110 });
      } else {
        Object.assign(fx, { assemble: seg(t, S.boom, S.boom + 0.9), keepCore: true, flash: 0.9 * (1 - seg(t, S.boom, S.boom + 0.3)) });
        if (from.div && to.div) fx.numFlip = { from: from.div, to: to.div, p: seg(t, S.boom + 0.1, S.boom + 0.5) };
      }
      const ti = Math.max(0, t - S.impact);
      if (t >= S.impact) punch = 1 + 0.18 * Math.exp(-ti * 6) * Math.cos(ti * 18);
      fx.idle = t >= S.impact; fx.t = ti; fx.particles = seg(t, S.impact, S.impact + 0.6); fx.sheen = true;
    }
    if (!(kind === 'tier' && t >= S.boom && fx.assemble <= 0)) {
      ctx.save();
      const sx = shake * Math.sin(t * 61), sy = shake * Math.cos(t * 47);
      ctx.translate(cx + sx * k, cy + sy * k); ctx.scale(k * punch, k * punch); ctx.translate(-60, -58);
      if (gray > 0) ctx.filter = `saturate(${1 - gray}) brightness(${1 - gray * 0.25})`;
      drawBadge(ctx, tier, div, fx);
      ctx.restore();
    }
    // 衝擊波、白光、彩帶
    if (kind !== 'down') {
      ring(ctx, cx, cy, seg(t, S.boom, S.boom + 0.7), Math.max(W, H) * 0.9, '#FFFFFF');
      if (kind === 'tier') ring(ctx, cx, cy, seg(t, S.impact, S.impact + 0.8), Math.max(W, H) * 0.7, P[0]);
      const fl = kind === 'div' ? 0.6 : 1;
      const a = fl * (1 - seg(t, S.boom, S.boom + 0.5)) * (t >= S.boom ? 1 : 0);
      if (a > 0) { ctx.fillStyle = `rgba(255,255,255,${a})`; ctx.fillRect(0, 0, W, H); }
      confetti(ctx, cx, cy, t - S.impact - 0.05, kind === 'div' ? 45 : 90, [P[0], P[1], '#FFD54A', '#FFFFFF', '#7D9BFF'], H);
    }
    // 文字
    const ty = cy + sz * 0.62;
    const title = kind === 'down' ? '掉段了' : kind === 'div' ? '升段！' : master ? '大師降臨！' : champ ? '登上王者！' : '晉級！';
    const tp = seg(t, S.title, S.title + 0.35);
    if (tp > 0) {
      ctx.save(); ctx.translate(cx, cy - sz * 0.72);
      const s = kind === 'down' ? 1 : 1 + 1.5 * (1 - easeOutBack(tp));
      ctx.scale(s, s); ctx.globalAlpha = tp; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.font = '900 40px -apple-system, "PingFang TC", sans-serif';
      if (kind !== 'down') { ctx.shadowColor = P[1]; ctx.shadowBlur = 24; }
      ctx.fillStyle = kind === 'down' ? '#9AA5B1' : P[0]; ctx.fillText(title, 0, 0);
      ctx.restore();
    }
    const name = BADGE.names[to.tier] + (to.div ? ' ' + ['I', 'II', 'III'][to.div - 1] : '');
    const np = seg(t, S.title + 0.3, S.title + 0.7);
    ctx.textAlign = 'center'; ctx.globalAlpha = np; ctx.fillStyle = '#E9EDF2';
    ctx.font = '800 26px -apple-system, "PingFang TC", sans-serif'; ctx.fillText(name, cx, ty + 20 * (1 - easeOutCubic(np)));
    ctx.globalAlpha = seg(t, S.title + 0.6, S.title + 1); ctx.fillStyle = '#9AA5B1'; ctx.font = '16px -apple-system, "PingFang TC", sans-serif';
    ctx.fillText(kind === 'down' ? '沒關係，這週多練一次就拿回來。' : '繼續保持，下一段在等你。', cx, ty + 52);
    ctx.globalAlpha = 1;
  }

  // ---------- 預覽頁 ----------
  const root = document.getElementById('anim');
  const css = 'display:inline-block;text-align:center;vertical-align:top;margin:4px';
  root.innerHTML = `<h3 style="margin:6px 4px">待機動畫（看牌位時）</h3><div id=idle></div>
    <h3 style="margin:14px 4px 6px">晉級／掉段</h3><div id=btns style="margin:4px"></div>
    <canvas id=scene width=390 height=640 style="width:390px;height:640px;border-radius:24px;border:1px solid #2A3340"></canvas>`;
  const idle = document.getElementById('idle');
  const cards = [];
  const SZ = 150, PAD = 1.6;
  BADGE.tiers.forEach((looks, ti) => {
    (ti < 6 ? [3, 2, 1] : [null]).forEach((div) => {
      const c = document.createElement('canvas');
      const px = Math.round(SZ * PAD);
      c.width = px * 2; c.height = px * 2; c.style.width = c.style.height = px + 'px';
      const w = document.createElement('span'); w.style.cssText = css;
      w.appendChild(c); w.appendChild(document.createElement('br'));
      const lab = document.createElement('small'); lab.textContent = BADGE.names[ti] + (div ? ' ' + ['I', 'II', 'III'][div - 1] : ''); w.appendChild(lab);
      idle.appendChild(w); cards.push({ c, ti, div, px });
    });
  });
  const R = (tier, div) => ({ tier, div, idx: tier * 3 + (div ? 3 - div : 0) });
  const demos = [
    ['鐵 III → 鐵 II', R(0, 3), R(0, 2)], ['鐵 I → 銅 III', R(0, 1), R(1, 3)], ['銀 I → 金 III', R(2, 1), R(3, 3)],
    ['金 II → 金 I', R(3, 2), R(3, 1)], ['白金 I → 鑽石 III', R(4, 1), R(5, 3)], ['鑽石 I → 大師', R(5, 1), R(6, null)],
    ['大師 → 王者', R(6, null), R(7, null)], ['銅 II → 銅 III（掉段）', R(1, 2), R(1, 3)], ['金 III → 銀 I（掉段）', R(3, 3), R(2, 1)],
  ];
  let cur = demos[1], start = performance.now();
  const btns = document.getElementById('btns');
  demos.forEach((d) => {
    const b = document.createElement('button'); b.textContent = d[0];
    b.style.cssText = 'margin:3px;padding:6px 10px;background:#232C39;color:#E9EDF2;border:1px solid #2A3340;border-radius:8px';
    b.onclick = () => { cur = d; start = performance.now(); }; btns.appendChild(b);
  });
  const sc = document.getElementById('scene');
  sc.width = 780; sc.height = 1280;
  const fixed = new URLSearchParams(location.search);
  window.BADGE_RENDER = { drawBadge, scene, demos, setTime: null };
  function frame(now) {
    const t = fixed.has('t') ? Number(fixed.get('t')) : (now - start) / 1000;
    for (const k of cards) {
      const ctx = k.c.getContext('2d');
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, k.c.width, k.c.height);
      const s = (SZ / 120) * 2, off = (k.px - SZ) / 2 * 2;
      ctx.translate(off, off); ctx.scale(s, s);
      drawBadge(ctx, k.ti, k.div, { t: fixed.has('t') ? t : now / 1000, idle: true, particles: 1, sheen: true });
    }
    if (fixed.has('demo')) cur = demos[Number(fixed.get('demo'))];
    const ctx = sc.getContext('2d');
    ctx.setTransform(2, 0, 0, 2, 0, 0);
    scene(ctx, 390, 640, cur[1], cur[2], fixed.has('st') ? Number(fixed.get('st')) : t % 6.5);
    if (!fixed.has('t')) requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
