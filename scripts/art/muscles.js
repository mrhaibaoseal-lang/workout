// 人體肌肉圖：正面、背面。部位熱圖、疲勞地圖、身形圖共用。
// node scripts/art/muscles.js [預覽.html] → 產生 Workout/Art/MuscleArt.swift（與預覽）。
//
// 座標：x = 0 是中線，頭頂 y = 0，腳底 y ≈ 424。手臂微張（A 字站姿）。
// 四肢沿骨頭方向畫：limb(u, v)，u = 0（近端）→ 1（遠端），v = −1（內側）→ +1（外側）。
// 畫法：先畫身體外形（含外框），肌肉「裁切在身體裡面」，所以貼邊的肌肉會跟外框齊平；
// 肌肉之間用背景色的細線分開。左半邊畫好後自動鏡像到右邊。
// zone：身形圖縮放用（core＝以中線縮放；arm／leg＝沿肢段中心線縮放粗細；head＝不縮放）。
const fs = require('fs');
const path = require('path');

const f = (n) => (Math.round(n * 10) / 10).toString();

/** 閉合的平滑曲線，經過每個點（Catmull-Rom → 三次貝茲）。 */
function smooth(pts, t = 1) {
  const n = pts.length;
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6 * t, p1[1] + (p2[1] - p0[1]) / 6 * t];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6 * t, p2[1] - (p3[1] - p1[1]) / 6 * t];
    d += ` C${f(c1[0])} ${f(c1[1])} ${f(c2[0])} ${f(c2[1])} ${f(p2[0])} ${f(p2[1])}`;
  }
  return d + ' Z';
}
const mirror = (pts) => pts.map(([x, y]) => [-x, y]).reverse();
const sym = (left) => [...left, ...mirror(left)];

/** 肢段：A→B，profile = [[u, 外側半寬, 內側半寬]...]。 */
function limb(A, B, profile) {
  const dx = B[0] - A[0], dy = B[1] - A[1], L = Math.hypot(dx, dy);
  const n = [-dy / L, dx / L]; // 左半邊：指向外側（x 變小）
  const w = (u, v) => {
    const k = v >= 0 ? 1 : 2;
    if (u <= profile[0][0]) return profile[0][k];
    for (let i = 0; i < profile.length - 1; i++) {
      const a = profile[i], b = profile[i + 1];
      if (u <= b[0]) return a[k] + (b[k] - a[k]) * (u - a[0]) / (b[0] - a[0]);
    }
    return profile[profile.length - 1][k];
  };
  const P = (u, v) => {
    const ww = w(u, v);
    return [A[0] + dx * u + n[0] * v * ww, A[1] + dy * u + n[1] * v * ww];
  };
  P.outline = (u0 = 0, u1 = 1, steps = 8) => {
    const out = [], inn = [];
    for (let i = 0; i <= steps; i++) {
      const u = u0 + (u1 - u0) * i / steps;
      out.push(P(u, 1));
      inn.push(P(u, -1));
    }
    return [...out, ...inn.reverse()];
  };
  P.map = (uv) => uv.map(([u, v]) => P(u, v));
  P.A = A; P.B = B;
  return P;
}

// ───────── 骨架（左半邊） ─────────
const upper = limb([-60, 84], [-80, 170], [[0, 17, 14], [0.25, 15, 13], [0.6, 12.5, 11], [1, 9.5, 9]]);
const fore = limb([-80, 170], [-97, 252], [[0, 10, 9.5], [0.25, 12.5, 10.5], [0.6, 9, 8], [1, 6.5, 6]]);
const hand = limb([-97, 252], [-105, 296], [[0, 6.5, 6], [0.35, 9, 8.5], [0.7, 8, 7.5], [1, 4.5, 4]]);
const thigh = limb([-25, 196], [-28, 306], [[0, 23, 19], [0.2, 24.5, 19], [0.7, 18, 15], [1, 13, 13]]);
const shin = limb([-28, 306], [-26, 402], [[0, 13.5, 13], [0.28, 18.5, 16.5], [0.6, 12.5, 11.5], [0.9, 8, 7.5], [1, 8, 8]]);

// 形狀清單：side: 'L' 左（會再鏡像出右）、'C' 置中（已對稱）
const S = [];
// 比例校正：頭 1/8 身高、胸線 2 頭、肚臍 3 頭、胯下在身高一半（軀幹和手臂往上壓縮，肩寬略收）
function fixY(y) {
  const k = [[0, 0], [49, 54], [76, 68], [248, 210]];
  if (y >= 248) return 210 + (y - 248) * 0.84;
  for (let i = 1; i < k.length; i++) {
    if (y <= k[i][0]) return k[i - 1][1] + (y - k[i - 1][0]) * (k[i][1] - k[i - 1][1]) / (k[i][0] - k[i - 1][0]);
  }
  return y;
}
const fix = (zone) => ([x, y]) => zone === 'head' ? [x * 1.1, y * 1.1] : zone === 'leg' ? [x, y] : [x * 0.95, fixY(y)];
function add(view, muscle, zone, pts, side = 'L', t = 1) { S.push({ view, muscle, zone, pts: pts.map(fix(zone)), side, t }); }
const both = (fn) => { fn('front'); fn('back'); };

// ───────── 身體外形 ─────────
both((v) => {
  add(v, 'body', 'head', [[0, 0], [11, 2], [16, 12], [16.5, 25], [14, 36], [9, 45], [0, 49], [-9, 45], [-14, 36],
    [-16.5, 25], [-16, 12], [-11, 2]], 'C');
  add(v, 'body', 'head', [[-15, 22], [-19, 24], [-19, 32], [-15, 34]], 'L', 0.8); // 耳朵
  add(v, 'body', 'core', sym([[0, 36], [-11, 38], [-12, 56], [-22, 66], [-42, 74], [-56, 80], [-62, 92], [-56, 120],
    [-50, 140], [-45, 168], [-42, 186], [-46, 204], [-49, 222], [-46, 240], [-14, 244], [0, 248]]), 'C');
  add(v, 'body', 'arm', upper.outline(0, 1, 6), 'L', 0.9);
  add(v, 'body', 'arm', fore.outline(-0.05, 1, 6), 'L', 0.9);
  add(v, 'body', 'arm', [...hand.map([[0, 1], [0.4, 1.05], [0.75, 0.95], [1, 0.5], [1.02, -0.2], [0.8, -0.8], [0.45, -1]]),
    ...hand.map([[0.35, -1.25], [0.55, -1.9], [0.62, -1.6], [0.3, -1.1], [0.05, -1]])], 'L', 0.8);
  add(v, 'body', 'arm', [[-48, 76], [-64, 72], [-78, 84], [-82, 104], [-78, 124], [-66, 104], [-56, 92]]); // 肩頭
  add(v, 'body', 'leg', thigh.outline(0.04, 1, 6), 'L', 0.9);
  add(v, 'body', 'leg', shin.outline(-0.02, 1, 7), 'L', 0.9);
  add(v, 'body', 'leg', [[-18, 398], [-34, 398], [-38, 412], [-36, 424], [-14, 424], [-15, 410]], 'L', 0.8); // 腳
});

// ───────── 正面肌肉 ─────────
add('front', null, 'core', [[-7, 74], [-10, 58], [-13, 50], [-15, 54], [-12, 70]], 'L', 0.8); // 胸鎖乳突肌
add('front', 'traps', 'core', [[-14, 58], [-26, 68], [-46, 77], [-26, 78], [-15, 70]]);
add('front', 'frontDelt', 'arm', [[-38, 78], [-58, 76], [-66, 90], [-68, 110], [-66, 128], [-58, 116], [-50, 100], [-44, 88]]);
add('front', 'sideDelt', 'arm', [[-58, 74], [-72, 80], [-80, 98], [-79, 118], [-72, 132], [-67, 114], [-65, 92]]);
add('front', 'chest', 'core', [[-3, 82], [-18, 79], [-38, 80], [-52, 92], [-60, 112], [-52, 128], [-32, 136], [-12, 134], [-3, 126]]);
add('front', 'chest', 'core', [[-3, 82], [-18, 79], [-38, 80], [-50, 90], [-32, 95], [-12, 94], [-3, 92]], 'L', 0.8); // 上胸
add('front', 'biceps', 'arm', upper.map([[0.32, -0.55], [0.3, 0.2], [0.42, 0.6], [0.7, 0.55], [0.92, 0.2], [0.94, -0.4], [0.7, -0.8], [0.45, -0.85]]));
add('front', 'triceps', 'arm', upper.map([[0.4, -0.9], [0.65, -0.95], [0.9, -0.75], [0.95, -1.3], [0.4, -1.3]]));
add('front', 'forearms', 'arm', fore.map([[0.02, 0.2], [0.05, 1.3], [0.35, 1.3], [0.7, 1.2], [0.75, 0.5], [0.4, 0.15]]));
add('front', 'forearms', 'arm', fore.map([[0.05, 0.1], [0.4, 0.05], [0.8, 0.4], [0.95, -0.2], [0.8, -1.3], [0.3, -1.3], [0.05, -1.2]]));
for (const [y0, y1] of [[140, 160], [163, 183], [186, 206]]) {
  add('front', 'abs', 'core', [[-3, y0], [-19, y0 + 1.5], [-21, (y0 + y1) / 2], [-20, y1], [-3, y1]], 'L', 0.6);
}
add('front', 'abs', 'core', [[-3, 209], [-19, 210], [-17, 226], [-10, 240], [-3, 244]], 'L', 0.7);
add('front', 'obliques', 'core', [[-24, 150], [-42, 146], [-50, 168], [-45, 196], [-38, 220], [-28, 230], [-23, 206], [-22, 176]]);
for (const [y, x] of [[128, -45], [138, -48], [148, -50]]) {
  add('front', 'obliques', 'core', [[x + 4, y], [x - 8, y - 4], [x - 9, y + 4], [x + 2, y + 7]], 'L', 0.7); // 前鋸肌
}
add('front', null, 'leg', thigh.map([[0.02, 0.6], [0.02, 1.3], [0.2, 1.2], [0.25, 0.85]])); // 闊筋膜張肌
add('front', 'quads', 'leg', thigh.map([[0.08, 0.95], [0.3, 1.15], [0.6, 1.2], [0.86, 0.9], [0.9, 0.35], [0.55, 0.45], [0.25, 0.6]]));
add('front', 'quads', 'leg', thigh.map([[0.06, 0.45], [0.3, 0.55], [0.62, 0.42], [0.84, 0.1], [0.66, -0.35], [0.35, -0.45], [0.12, -0.2]]));
add('front', 'quads', 'leg', thigh.map([[0.58, -0.55], [0.7, -0.1], [0.92, 0.1], [0.98, -0.6], [0.9, -1.25], [0.72, -1.2]]));
add('front', null, 'leg', thigh.map([[0.0, -0.3], [0.05, -1.3], [0.55, -1.3], [0.6, -0.75], [0.3, -0.55]])); // 內收肌
add('front', null, 'leg', thigh.map([[0.93, -0.5], [0.95, 0.5], [1.05, 0.6], [1.08, -0.5]]), 'L', 0.9); // 膝蓋
add('front', null, 'leg', shin.map([[0.08, 0.15], [0.07, 0.75], [0.4, 0.8], [0.75, 0.55], [0.85, 0.25], [0.5, 0.05]])); // 脛前肌
add('front', 'calves', 'leg', shin.map([[0.08, 0.95], [0.3, 1.3], [0.6, 1.3], [0.62, 0.85], [0.3, 0.85]]));
add('front', 'calves', 'leg', shin.map([[0.08, -0.4], [0.3, -0.3], [0.58, -0.55], [0.6, -1.3], [0.25, -1.3], [0.08, -1.1]]));

// ───────── 背面肌肉 ─────────
add('back', 'traps', 'core', sym([[0, 50], [-10, 58], [-28, 70], [-50, 78], [-40, 88], [-26, 104], [-14, 140], [0, 168]]), 'C');
add('back', 'rearDelt', 'arm', [[-50, 78], [-68, 76], [-79, 94], [-79, 116], [-72, 132], [-64, 114], [-58, 94]]);
add('back', 'traps', 'core', [[-28, 102], [-42, 92], [-58, 100], [-58, 116], [-46, 124], [-32, 118]]); // 棘下肌、大圓肌（上背）
add('back', 'lats', 'core', [[-18, 132], [-30, 122], [-46, 126], [-58, 128], [-56, 150], [-48, 180], [-36, 204], [-20, 214], [-13, 196], [-14, 160]]);
add('back', 'lowerBack', 'core', [[-3, 168], [-12, 172], [-15, 204], [-11, 222], [-3, 224]], 'L', 0.8);
add('back', 'obliques', 'core', [[-36, 206], [-46, 196], [-46, 214], [-40, 224], [-28, 222]], 'L', 0.8);
add('back', 'glutes', 'core', [[-34, 216], [-46, 212], [-50, 232], [-40, 226]], 'L', 0.8); // 臀中肌
add('back', 'glutes', 'core', [[-3, 236], [-18, 222], [-38, 224], [-52, 244], [-52, 270], [-36, 286], [-14, 286], [-3, 272]]);
add('back', null, 'leg', thigh.map([[0.32, 0.9], [0.32, 1.3], [0.95, 1.3], [0.92, 0.9]]), 'L', 0.6); // 髂脛束
add('back', 'hamstrings', 'leg', thigh.map([[0.34, 0.0], [0.4, 0.85], [0.7, 0.85], [0.92, 0.7], [0.98, 0.3], [0.75, 0.05]]));
add('back', 'hamstrings', 'leg', thigh.map([[0.34, -0.05], [0.75, -0.02], [0.98, -0.3], [0.92, -0.85], [0.6, -0.95], [0.38, -0.85]]));
add('back', null, 'leg', thigh.map([[0.32, -0.9], [0.62, -1.0], [0.4, -1.3], [0.3, -1.3]]), 'L', 0.7); // 內收肌
add('back', 'calves', 'leg', shin.map([[0.35, -1.2], [0.75, -0.8], [0.8, 0.8], [0.35, 1.2]]), 'L', 0.8); // 比目魚肌
add('back', 'calves', 'leg', shin.map([[0.04, -0.05], [0.04, -0.9], [0.25, -1.2], [0.55, -0.8], [0.62, -0.25], [0.45, -0.05]]));
add('back', 'calves', 'leg', shin.map([[0.04, 0.05], [0.04, 0.9], [0.25, 1.15], [0.5, 0.75], [0.55, 0.25], [0.4, 0.05]]));
add('back', 'triceps', 'arm', upper.map([[0.3, 0.3], [0.32, 1.2], [0.7, 1.1], [0.88, 0.5], [0.75, 0.05]]));
add('back', 'triceps', 'arm', upper.map([[0.3, 0.2], [0.75, -0.02], [0.92, 0.3], [0.95, -0.6], [0.75, -1.2], [0.35, -1.2]]));
add('back', 'forearms', 'arm', fore.map([[0.02, -0.1], [0.05, -1.3], [0.4, -1.3], [0.8, -1.0], [0.75, -0.2], [0.4, -0.15]]));
add('back', 'forearms', 'arm', fore.map([[0.05, 0.0], [0.4, -0.05], [0.8, 0.0], [0.95, 0.6], [0.7, 1.3], [0.3, 1.3], [0.05, 1.2]]));

// ───────── 輸出 ─────────
function shapes(view) {
  const out = [];
  for (const s of S.filter((x) => x.view === view)) {
    out.push({ muscle: s.muscle, zone: s.zone, d: smooth(s.pts, s.t) });
    if (s.side === 'L') out.push({ muscle: s.muscle, zone: s.zone, d: smooth(mirror(s.pts), s.t) });
  }
  return out;
}
const ART = { front: shapes('front'), back: shapes('back') };
// 四肢中心線（左半邊，身形圖沿這條線縮放粗細）
const AXES = { arm: [upper.A, upper.B, fore.B, hand.B].map(fix('arm')), leg: [thigh.A, thigh.B, shin.B, [-26, 424]] };
module.exports = { ART, AXES };

if (require.main === module) {
  const pt = (p) => `CGPoint(x: ${f(p[0])}, y: ${f(p[1])})`;
  const swift = [
    '// 自動產生，請勿手改：node scripts/art/muscles.js',
    '// 人體正面、背面的外形和肌肉（座標說明見 scripts/art/muscles.js 開頭）。',
    '// 畫法：先畫 muscle == "body" 的外形，再把其他形狀裁切在身體裡面畫。',
    '',
    'import CoreGraphics',
    '',
    'enum MuscleArt {',
    '    struct Shape {',
    '        /// Muscle.rawValue；"body" = 身體外形；nil = 不算部位的（膝蓋、內收肌、筋膜）',
    '        let muscle: String?',
    '        /// core／arm／leg／head：身形圖依圍度縮放用',
    '        let zone: String',
    '        let d: String',
    '    }',
    '',
    '    /// 左手臂中心線（肩 → 肘 → 腕 → 指尖），右邊 x 取負號',
    `    static let armAxis: [CGPoint] = [${AXES.arm.map(pt).join(', ')}]`,
    '    /// 左腿中心線（髖 → 膝 → 踝 → 腳底）',
    `    static let legAxis: [CGPoint] = [${AXES.leg.map(pt).join(', ')}]`,
    '',
  ];
  for (const view of ['front', 'back']) {
    swift.push(`    static let ${view}: [Shape] = [`);
    swift.push(ART[view].map((s) => `        Shape(muscle: ${s.muscle ? `"${s.muscle}"` : 'nil'}, zone: "${s.zone}", d: "${s.d}")`).join(',\n'));
    swift.push('    ]', '');
  }
  swift.push('}', '');
  fs.writeFileSync(path.join(__dirname, '../../Workout/Art/MuscleArt.swift'), swift.join('\n'));

  const preview = process.argv[2];
  if (preview) {
    const heat = { chest: '#5BD69A', frontDelt: '#5BD69A', sideDelt: '#F2C14E', rearDelt: '#46536A', traps: '#7D9BFF',
      biceps: '#5BD69A', triceps: '#F2C14E', forearms: '#7D9BFF', abs: '#FF8757', obliques: '#7D9BFF', lats: '#5BD69A',
      lowerBack: '#7D9BFF', glutes: '#F2C14E', quads: '#5BD69A', hamstrings: '#FF8757', calves: '#46536A' };
    const svg = (view, mode, id) => {
      const body = ART[view].filter((s) => s.muscle === 'body');
      const outline = body.map((s) => `<path d="${s.d}" fill="none" stroke="#141A22" stroke-width="2.6" stroke-linejoin="round"/>`).join('');
      const fill = body.map((s) => `<path d="${s.d}" fill="#353F4E"/>`).join('');
      const clip = `<clipPath id="c${id}">${body.map((s) => `<path d="${s.d}"/>`).join('')}</clipPath>`;
      const ms = ART[view].filter((s) => s.muscle !== 'body').map((s) => {
        const c = s.muscle ? (mode === 'heat' ? heat[s.muscle] : '#3B4759') : '#323C4A';
        return `<path d="${s.d}" fill="${c}" stroke="#141A22" stroke-width="1.1" stroke-linejoin="round"/>`;
      }).join('');
      return `<svg viewBox="-118 -6 236 436" width="300" height="554"><defs>${clip}</defs>${outline}${fill}<g clip-path="url(#c${id})">${ms}</g></svg>`;
    };
    const html = `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#0E1218;display:flex;gap:0;padding:8px;width:1220px">
${svg('front', 'plain', 1)}${svg('back', 'plain', 2)}${svg('front', 'heat', 3)}${svg('back', 'heat', 4)}</body>`;
    fs.writeFileSync(preview, html);
  }
}
