// 人體肌肉圖：正面、背面。部位熱圖、疲勞地圖、身形圖共用。
// node scripts/art/muscles.js [預覽.html] → 產生 Workout/Art/MuscleArt.swift（與預覽）。
//
// 座標：每個視圖 x = 0 是中線，頭頂 y = 0，腳底 y ≈ 402。
// 每塊用「左半邊的控制點」畫平滑曲線（Catmull-Rom 轉三次貝茲），右半邊自動鏡像。
// zone：身形圖縮放用（core＝以中線縮放；arm／leg＝以肢段中心線縮放粗細；head＝不縮放）。
const fs = require('fs');
const path = require('path');

const f = (n) => (Math.round(n * 10) / 10).toString();

/** 閉合的平滑曲線，經過每個點。 */
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
const mirror = (pts) => pts.map(([x, y]) => [-x, y]);
/** 左右對稱的一整塊（只給左半邊，從中線上方往下繞到中線下方）。 */
const sym = (left) => [...left, ...mirror(left).reverse()];

// 形狀清單：{ view, muscle, zone, pts, side }；side: 'L' 左（會再鏡像出右）、'C' 置中
const S = [];
function add(view, muscle, zone, pts, side = 'L', t = 1) { S.push({ view, muscle, zone, pts, side, t }); }

// ───────── 身體外形（兩個視圖共用，背面一樣） ─────────
for (const view of ['front', 'back']) {
  add(view, 'body', 'head', [[0, 0], [11, 2], [16, 12], [16, 25], [13, 35], [7, 43], [0, 45], [-7, 43], [-13, 35], [-16, 25], [-16, 12], [-11, 2]], 'C');
  add(view, 'body', 'core', sym([[-12, 36], [-13, 50], [-26, 60], [-46, 64], [-54, 74], [-50, 92], [-47, 110], [-42, 134],
    [-38, 158], [-41, 182], [-48, 202], [-50, 214], [-28, 220], [-6, 222]]), 'C');
  add(view, 'body', 'arm', [[-44, 63], [-60, 66], [-69, 80], [-70, 104], [-70, 128], [-73, 150], [-78, 176], [-78, 204],
    [-73, 226], [-77, 242], [-73, 258], [-64, 260], [-60, 244], [-59, 226], [-56, 200], [-52, 172], [-49, 150],
    [-48, 128], [-47, 100], [-44, 82]]);
  add(view, 'body', 'leg', [[-48, 200], [-53, 226], [-52, 258], [-45, 290], [-42, 304], [-48, 330], [-46, 360],
    [-39, 382], [-42, 395], [-36, 402], [-18, 402], [-20, 382], [-21, 344], [-21, 306], [-18, 290], [-13, 262],
    [-5, 224], [-2, 214], [-24, 206]]);
}

// ───────── 正面 ─────────
add('front', 'traps', 'core', [[-10, 50], [-22, 58], [-40, 65], [-24, 67], [-11, 61]]);
add('front', 'frontDelt', 'arm', [[-36, 66], [-50, 66], [-57, 78], [-58, 96], [-53, 110], [-47, 98], [-43, 84], [-38, 74]]);
add('front', 'sideDelt', 'arm', [[-54, 66], [-63, 70], [-68, 84], [-68, 102], [-62, 114], [-60, 96], [-59, 80]]);
add('front', 'chest', 'core', [[-3, 74], [-18, 70], [-36, 70], [-44, 80], [-46, 96], [-40, 108], [-24, 114], [-8, 114], [-3, 106]]);
add('front', 'biceps', 'arm', [[-52, 114], [-60, 110], [-66, 122], [-68, 138], [-64, 152], [-56, 150], [-52, 136], [-50, 124]]);
add('front', 'forearms', 'arm', [[-56, 158], [-66, 156], [-73, 172], [-75, 196], [-71, 222], [-64, 222], [-60, 200], [-56, 176]]);
for (const [y0, y1] of [[120, 139], [142, 160], [163, 182]]) {
  add('front', 'abs', 'core', [[-3, y0], [-16, y0 + 1], [-18, (y0 + y1) / 2], [-17, y1], [-3, y1]], 'L', 0.6);
}
add('front', 'abs', 'core', [[-3, 185], [-16, 186], [-14, 200], [-8, 210], [-3, 212]], 'L', 0.7);
add('front', 'obliques', 'core', [[-21, 124], [-34, 118], [-40, 134], [-37, 160], [-33, 182], [-27, 194], [-21, 186], [-21, 152]]);
add('front', 'quads', 'leg', [[-31, 210], [-45, 206], [-51, 226], [-50, 256], [-44, 282], [-35, 292], [-25, 288], [-20, 266],
  [-18, 238], [-22, 218]]);
add('front', null, 'leg', [[-6, 224], [-17, 222], [-17, 246], [-14, 266], [-9, 244]]);
add('front', 'calves', 'leg', [[-24, 310], [-38, 307], [-46, 326], [-44, 352], [-37, 372], [-29, 374], [-24, 350], [-22, 328]]);

// ───────── 背面 ─────────
add('back', 'traps', 'core', sym([[0, 44], [-10, 50], [-22, 58], [-40, 65], [-27, 73], [-15, 94], [-6, 120], [0, 128]]), 'C');
add('back', 'rearDelt', 'arm', [[-42, 66], [-58, 66], [-68, 80], [-68, 100], [-62, 112], [-54, 98], [-47, 80]]);
add('back', 'lats', 'core', [[-26, 82], [-42, 76], [-48, 92], [-46, 116], [-40, 146], [-30, 172], [-20, 186], [-12, 160],
  [-12, 126], [-19, 100]]);
add('back', 'triceps', 'arm', [[-52, 112], [-62, 110], [-68, 124], [-68, 142], [-63, 154], [-55, 150], [-51, 134]]);
add('back', 'forearms', 'arm', [[-56, 158], [-66, 156], [-73, 172], [-75, 196], [-71, 222], [-64, 222], [-60, 200], [-56, 176]]);
add('back', 'lowerBack', 'core', [[-3, 136], [-9, 138], [-11, 160], [-16, 188], [-10, 198], [-3, 196]]);
add('back', 'glutes', 'core', [[-3, 202], [-20, 194], [-40, 196], [-49, 214], [-46, 236], [-30, 248], [-10, 246], [-3, 232]]);
add('back', 'hamstrings', 'leg', [[-10, 250], [-26, 252], [-44, 248], [-50, 262], [-46, 284], [-38, 298], [-26, 298],
  [-16, 290], [-10, 272]]);
add('back', 'calves', 'leg', [[-30, 304], [-42, 306], [-48, 326], [-44, 350], [-36, 360], [-30, 344]]);
add('back', 'calves', 'leg', [[-29, 304], [-20, 306], [-19, 328], [-23, 352], [-29, 352]]);

// ───────── 輸出 ─────────
function shapes(view) {
  const out = [];
  for (const s of S.filter((x) => x.view === view)) {
    out.push({ muscle: s.muscle, zone: s.zone, d: smooth(s.pts, s.t) });
    if (s.side === 'L') out.push({ muscle: s.muscle, zone: s.zone, d: smooth(mirror(s.pts).reverse(), s.t) });
  }
  return out;
}
const ART = { front: shapes('front'), back: shapes('back') };
module.exports = { ART };

if (require.main === module) {
  const swift = [
    '// 自動產生，請勿手改：node scripts/art/muscles.js',
    '// 人體正面、背面的外形和肌肉（座標說明見 scripts/art/muscles.js 開頭）。',
    '',
    'enum MuscleArt {',
    '    struct Shape {',
    '        /// Muscle.rawValue；"body" = 身體外形；nil = 不算部位的（膝蓋、內收肌）',
    '        let muscle: String?',
    '        /// core／arm／leg／head：身形圖依圍度縮放用',
    '        let zone: String',
    '        let d: String',
    '    }',
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
    const colors = { traps: '#7D9BFF', frontDelt: '#FF8757', sideDelt: '#F2C14E', rearDelt: '#F2C14E', chest: '#5BD69A',
      biceps: '#C38BFF', triceps: '#C38BFF', forearms: '#8FA3B8', abs: '#FF6B8B', obliques: '#4FD1E0', lats: '#5BD69A',
      lowerBack: '#FF6B8B', glutes: '#FF8757', quads: '#7D9BFF', hamstrings: '#4FD1E0', calves: '#F2C14E' };
    const svg = (view, mode) => {
      const body = ART[view].filter((s) => s.muscle === 'body').map((s) => `<path d="${s.d}" fill="#2A3340"/>`).join('');
      const ms = ART[view].filter((s) => s.muscle !== 'body').map((s) => {
        const c = mode === 'color' ? (s.muscle ? colors[s.muscle] : '#3A4554') : (s.muscle ? '#46536A' : '#38424F');
        return `<path d="${s.d}" fill="${c}" stroke="#0E1218" stroke-width="1.6" stroke-linejoin="round"/>`;
      }).join('');
      return `<svg viewBox="-90 -6 180 414" width="270" height="621">${body}${ms}</svg>`;
    };
    const html = `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#0E1218;display:flex;gap:10px;padding:16px">
${svg('front', 'color')}${svg('back', 'color')}${svg('front', 'plain')}${svg('back', 'plain')}</body>`;
    fs.writeFileSync(preview, html);
  }
}
