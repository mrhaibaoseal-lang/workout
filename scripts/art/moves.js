// 動作示範、熱身、伸展的骨架動作（權威來源）。
//   node scripts/art/moves.js swift            產生 Workout/Character/MoveFrames.swift（不要手改產生的檔）
//   node scripts/art/moves.js preview out.png [id,id…]   截預覽：每個動作畫 5 個時間點
//
// 座標和 CharacterPose.swift 一樣：側面、面向右，200 單位，y 向下，地面 y=184（腳踝約 182）。
// 用「角度」描述每一段，肢體長度固定，換姿勢不會變形。角度：0＝往右、90＝往下、-90＝往上、180＝往左。
//   hip: 髖的位置（會被 anchor 平移）
//   torso: 髖→肩的角度；neck: 肩→頭（預設和 torso 一樣）
//   arm: [上臂, 前臂]；leg: [大腿, 小腿, 腳掌]
//   farArm / farLeg: 遠側的手腳另外擺（沒寫就跟近側一樣，只往後錯開一點）
//   anchor: [關節, x, y]，整個姿勢平移到讓那個關節落在這裡（例如 ['an', 106, 182] 腳踩地）
//     關節可以寫 'fan'、'fkn'、'fha'…（遠側）
const path = require('path');
const fs = require('fs');

const LEN = { torso: 50, neck: 22, upper: 28, fore: 24, thigh: 36, shin: 36, foot: 16 };
const FAR = [-6, -1];
const rad = (d) => (d * Math.PI) / 180;
const step = (p, ang, len) => [p[0] + Math.cos(rad(ang)) * len, p[1] + Math.sin(rad(ang)) * len];

function fk(s) {
  const hip = s.hip || [0, 0];
  const sh = step(hip, s.torso, LEN.torso);
  const head = step(sh, s.neck ?? s.torso, LEN.neck);
  const limb = (o, a, l1, l2) => { const m = step(o, a[0], l1); return [m, step(m, a[1], l2)]; };
  const [el, ha] = limb(sh, s.arm, LEN.upper, LEN.fore);
  const [kn, an] = limb(hip, s.leg, LEN.thigh, LEN.shin);
  const P = { head, sh, el, ha, hip, kn, an };
  const fsh = [sh[0] + FAR[0], sh[1] + FAR[1]];
  const fhip = [hip[0] + FAR[0], hip[1] + FAR[1]];
  if (s.farArm) { const [e, h] = limb(fsh, s.farArm, LEN.upper, LEN.fore); P.fel = e; P.fha = h; }
  if (s.farLeg) { const [k, a] = limb(fhip, s.farLeg, LEN.thigh, LEN.shin); P.fkn = k; P.fan = a; }
  const get = (j) => {
    if (P[j]) return P[j];
    if (j[0] === 'f') { const b = P[j.slice(1)]; return [b[0] + FAR[0], b[1] + FAR[1]]; }
    throw new Error('joint ' + j);
  };
  const [aj, ax, ay] = s.anchor || ['an', 106, 182];
  const a = get(aj);
  const dx = ax - a[0], dy = ay - a[1];
  for (const k in P) P[k] = [P[k][0] + dx, P[k][1] + dy];
  // 腳掌：有寫角度就照寫的；沒寫的話，踩在地上就平貼地面、腳尖朝膝蓋那一側，
  // 懸空就跟小腿垂直、朝身體正面（翻面的仰躺動作正面在另一側）。
  const foot = (knee, ankle, given) => {
    let ang = given;
    if (ang === undefined) {
      if (ankle[1] >= 176) {
        const d = knee[0] - ankle[0];
        ang = Math.abs(d) > 4 ? (d > 0 ? 0 : 180) : (s.mirror ? 180 : 0);
      } else {
        const shin = Math.atan2(ankle[1] - knee[1], ankle[0] - knee[0]) * 180 / Math.PI;
        ang = shin + (s.mirror ? 90 : -90);
      }
    }
    return step(ankle, ang, LEN.foot);
  };
  P.to = foot(P.kn, P.an, s.leg[2]);
  if (s.farLeg) P.fto = foot(P.fkn, P.fan, s.farLeg[2]);
  for (const k in P) P[k] = [+P[k][0].toFixed(1), +P[k][1].toFixed(1)];
  return P;
}

// 共用的站姿
const stand = { torso: -92, neck: -86, arm: [92, 90], leg: [88, 92], anchor: ['an', 106, 182] };
const S = (o) => ({ ...stand, ...o });
// 仰躺：頭在右、腳在左（和臀橋一樣）
const lie = (o) => ({ mirror: true, torso: -2, neck: -6, arm: [100, 95], leg: [178, 182], anchor: ['hip', 92, 170], ...o });

const MOVES = {
  // ───── 練前動態熱身 ─────
  armCircle: {
    title: '手臂繞圈', gear: 'bare', loop: true, period: 2.4,
    frames: [90, 45, 0, -45, -90, -135, -180, -225].map((a) => S({ arm: [a, a] })),
  },
  hipHinge: {
    title: '徒手早安式', gear: 'bare', period: 2.8,
    frames: [
      S({ arm: [60, -150] }),
      { torso: -18, neck: -6, arm: [125, -60], leg: [72, 100], anchor: ['an', 108, 182] },
    ],
  },
  bwSquat: {
    title: '徒手深蹲', gear: 'bare', period: 2.6,
    frames: [
      S({ arm: [92, 90] }),
      { torso: -68, neck: -78, arm: [0, 0], leg: [12, 112], anchor: ['an', 108, 182] },
    ],
  },
  lungeStep: {
    title: '後跨弓步', gear: 'bare', period: 3,
    frames: [
      S({ arm: [100, -120], farLeg: [88, 92] }),
      { torso: -90, neck: -86, arm: [100, -120], leg: [8, 92], farLeg: [128, 178], anchor: ['an', 128, 182] },
    ],
  },
  armSwing: {
    title: '手臂前後開合', gear: 'bare', period: 1.8,
    frames: [S({ arm: [0, 0] }), S({ arm: [150, 160] })],
  },
  wallSlide: {
    title: '頭上推舉伸展', gear: 'bare', period: 2.8,
    frames: [S({ arm: [100, -95] }), S({ arm: [-95, -92] })],
  },
  legSwing: {
    title: '前後擺腿', gear: 'bare', period: 2.2,
    frames: [
      S({ arm: [10, -10], farArm: [80, 85], leg: [30, 40], farLeg: [90, 90], anchor: ['fan', 106, 182] }),
      S({ arm: [10, -10], farArm: [80, 85], leg: [125, 125], farLeg: [90, 90], anchor: ['fan', 106, 182] }),
    ],
  },
  bwBridge: {
    title: '臀橋', gear: 'bare', period: 2.6,
    frames: [
      lie({ torso: 0, neck: -4, leg: [-140, 120], arm: [178, 180], anchor: ['an', 62, 182] }),
      lie({ torso: 30, neck: 5, leg: [-178, 96], arm: [165, 175], anchor: ['an', 62, 182] }),
    ],
  },

  // ───── 練後伸展（靜態，只有呼吸的小起伏）─────
  chestStretch: {
    title: '胸肌伸展', gear: 'bare', period: 5,
    frames: [S({ torso: -94, neck: -84, arm: [125, 130] }), S({ torso: -97, neck: -84, arm: [135, 140] })],
  },
  crossBody: {
    title: '手臂橫拉', gear: 'bare', period: 5,
    frames: [
      S({ arm: [-5, 2], farArm: [60, -10] }),
      S({ arm: [-8, 0], farArm: [58, -14] }),
    ],
  },
  tricepsStretch: {
    title: '三頭伸展', gear: 'bare', period: 5,
    frames: [
      S({ arm: [-100, 110], farArm: [-30, -110] }),
      S({ arm: [-104, 112], farArm: [-34, -112] }),
    ],
  },
  childPose: {
    title: '嬰兒式', gear: 'bare', period: 5,
    frames: [
      { torso: 14, neck: 22, arm: [6, 2], leg: [42, 180, 180], anchor: ['kn', 104, 177] },
      { torso: 11, neck: 18, arm: [3, 0], leg: [46, 180, 180], anchor: ['kn', 104, 177] },
    ],
  },
  quadStretch: {
    title: '站姿大腿前側伸展', gear: 'bare', period: 5,
    frames: [
      S({ arm: [110, 105], farArm: [10, 0], leg: [100, -115, -150], farLeg: [90, 90], anchor: ['fan', 108, 182] }),
      S({ arm: [112, 106], farArm: [6, -4], leg: [104, -112, -150], farLeg: [90, 90], anchor: ['fan', 108, 182] }),
    ],
  },
  seatedFold: {
    title: '坐姿體前彎', gear: 'bare', period: 5,
    frames: [
      { torso: -45, neck: -30, arm: [35, 15], leg: [2, 0, -88], anchor: ['hip', 70, 172] },
      { torso: -35, neck: -22, arm: [28, 10], leg: [2, 0, -88], anchor: ['hip', 70, 172] },
    ],
  },
  kneeHug: {
    title: '仰躺抱膝', gear: 'bare', period: 5,
    frames: [
      lie({ torso: 0, arm: [-150, 150], leg: [-125, 110], anchor: ['hip', 96, 172] }),
      lie({ torso: 0, arm: [-145, 150], leg: [-130, 108], anchor: ['hip', 96, 172] }),
    ],
  },
  calfStretch: {
    title: '推牆小腿伸展', gear: 'bare', period: 5, prop: 'wall',
    frames: [
      { torso: -62, neck: -55, arm: [-20, -2], leg: [118, 118], farLeg: [65, 105], anchor: ['an', 60, 182] },
      { torso: -58, neck: -52, arm: [-16, 2], leg: [120, 120], farLeg: [62, 108], anchor: ['an', 58, 182] },
    ],
  },
  hipFlexor: {
    title: '跪姿髖屈肌伸展', gear: 'bare', period: 5,
    frames: [
      { torso: -92, neck: -86, arm: [80, 40], leg: [100, 180, 178], farLeg: [0, 92], anchor: ['kn', 98, 178] },
      { torso: -90, neck: -86, arm: [80, 40], leg: [106, 180, 178], farLeg: [-4, 96], anchor: ['kn', 94, 178] },
    ],
  },
  cobra: {
    title: '人面獅身式', gear: 'bare', period: 5,
    frames: [
      { torso: -22, neck: -40, arm: [96, -2], leg: [176, 180, 160], anchor: ['hip', 100, 176] },
      { torso: -26, neck: -46, arm: [94, -2], leg: [176, 180, 160], anchor: ['hip', 100, 176] },
    ],
  },

  // ───── 訓練動作示範（比原本依動作模式套用的更貼近）─────
  splitSquat: {
    title: '保加利亞分腿蹲', gear: 'db', period: 2.8, prop: 'benchBack',
    frames: [
      { ...stand, arm: [92, 90], leg: [70, 106], farLeg: [118, 154, 175], anchor: ['an', 132, 182] },
      { torso: -88, neck: -84, arm: [92, 90], leg: [12, 100], farLeg: [100, 168, 175], anchor: ['an', 132, 182] },
    ],
  },
  reverseLunge: {
    title: '後跨弓步', gear: 'db', period: 3,
    frames: [
      S({ farLeg: [88, 92] }),
      { torso: -90, neck: -86, arm: [92, 90], leg: [8, 92], farLeg: [128, 178], anchor: ['an', 128, 182] },
    ],
  },
  stepUp: {
    title: '登階', gear: 'db', period: 3, prop: 'benchFront',
    frames: [
      { torso: -80, neck: -80, arm: [92, 90], leg: [-20, 105], farLeg: [95, 92], anchor: ['fan', 96, 182] },
      { torso: -90, neck: -86, arm: [92, 90], leg: [88, 92], farLeg: [88, 92], anchor: ['an', 128, 144] },
    ],
  },
  hipThrust: {
    title: '臀推', gear: 'db', period: 2.8, prop: 'benchBack',
    frames: [
      { torso: -150, neck: -170, arm: [-20, 0], leg: [-20, 95], anchor: ['an', 124, 182] },
      { torso: -178, neck: 175, arm: [10, -30], leg: [0, 90], anchor: ['an', 124, 182] },
    ],
  },
  benchPress: {
    title: '臥推', gear: 'db', period: 2.6, prop: 'benchFlat',
    frames: [
      lie({ torso: -2, neck: -4, arm: [-88, -90], leg: [175, 95], anchor: ['hip', 84, 144] }),
      lie({ torso: -2, neck: -4, arm: [140, -80], leg: [175, 95], anchor: ['hip', 84, 144] }),
    ],
  },
  floorPress: {
    title: '地板臥推', gear: 'db', period: 2.6,
    frames: [
      lie({ torso: -2, neck: -4, arm: [-88, -90], leg: [-150, 112], anchor: ['an', 62, 182] }),
      lie({ torso: -2, neck: -4, arm: [160, -85], leg: [-150, 112], anchor: ['an', 62, 182] }),
    ],
  },
  skullCrusher: {
    title: '仰臥三頭伸展', gear: 'db', period: 2.6, prop: 'benchFlat',
    frames: [
      lie({ torso: -2, neck: -4, arm: [-78, -80], leg: [175, 95], anchor: ['hip', 84, 144] }),
      lie({ torso: -2, neck: -4, arm: [-78, 30], leg: [175, 95], anchor: ['hip', 84, 144] }),
    ],
  },
  pullover: {
    title: '仰臥拉舉', gear: 'goblet', period: 3, prop: 'benchFlat',
    frames: [
      lie({ torso: -2, neck: -4, arm: [-85, -88], leg: [175, 95], anchor: ['hip', 84, 144] }),
      lie({ torso: -2, neck: -4, arm: [-15, -10], leg: [175, 95], anchor: ['hip', 84, 144] }),
    ],
  },
  kickback: {
    title: '三頭後踢', gear: 'db', period: 2.4,
    frames: [
      { torso: -28, neck: -14, arm: [135, 75], farArm: [70, 85], leg: [72, 102], anchor: ['an', 108, 182] },
      { torso: -28, neck: -14, arm: [138, 145], farArm: [70, 85], leg: [72, 102], anchor: ['an', 108, 182] },
    ],
  },
  pikePushup: {
    title: '屈體伏地挺身', gear: 'bare', period: 2.6,
    frames: [
      { torso: 25, neck: 60, arm: [65, 75], leg: [105, 105], anchor: ['an', 58, 182] },
      { torso: 50, neck: 95, arm: [20, 77], leg: [105, 105], anchor: ['an', 58, 182] },
    ],
  },
  reverseCrunch: {
    title: '反向捲腹', gear: 'bare', period: 2.6,
    frames: [
      lie({ torso: -2, arm: [178, 178], leg: [-90, 180], anchor: ['hip', 92, 172] }),
      lie({ torso: 8, arm: [178, 178], leg: [-45, 150], anchor: ['hip', 96, 168] }),
    ],
  },
  deadBug: {
    title: '死蟲式', gear: 'bare', period: 3,
    frames: [
      lie({ torso: -2, arm: [-90, -90], leg: [-90, 180], anchor: ['hip', 92, 172] }),
      lie({ torso: -2, arm: [-20, -15], farArm: [-90, -90], leg: [-90, 180], farLeg: [-176, -178], anchor: ['hip', 92, 172] }),
    ],
  },
  slRdl: {
    title: '單腳羅馬尼亞硬舉', gear: 'db', period: 3,
    frames: [
      S({ leg: [92, 92], farLeg: [88, 92], anchor: ['fan', 106, 182] }),
      { torso: -8, neck: 0, arm: [92, 90], leg: [176, 178], farLeg: [80, 98], anchor: ['fan', 106, 182] },
    ],
  },
  legCurl: {
    title: '俯臥腿後彎舉', gear: 'goblet', period: 2.6, prop: 'benchFlat',
    frames: [
      { torso: 0, neck: -10, arm: [60, 90], leg: [180, 182], anchor: ['hip', 96, 136] },
      { torso: 0, neck: -10, arm: [60, 90], leg: [180, -60], anchor: ['hip', 96, 136] },
    ],
  },
};

const ORDER = ['head', 'sh', 'el', 'ha', 'hip', 'kn', 'an', 'to'];
const FAR_ORDER = ['fel', 'fha', 'fkn', 'fan', 'fto'];

function framesOf(id) { return MOVES[id].frames.map(fk); }
function isMirror(m) { return m.frames.some((f) => f.mirror); }

function toSwift() {
  const n = (v) => (Number.isInteger(v) ? String(v) : v.toFixed(1).replace(/\.0$/, ''));
  let s = '// 由 scripts/art/moves.js 產生，不要手改。\n// swiftlint:disable all\nimport CoreGraphics\n\n';
  // 一個動作一句，避免整個大字典一起做型別推斷（編譯會很慢）
  s += 'extension CharacterMove {\n    /// rawValue → 動作資料\n    static let generated: [String: MoveSpec] = {\n        var d: [String: MoveSpec] = [:]\n';
  for (const id of Object.keys(MOVES)) {
    const m = MOVES[id];
    s += `        d["${id}"] = MoveSpec(title: "${m.title}", gear: .${m.gear}, loop: ${!!m.loop}, period: ${m.period}, prop: ${m.prop ? '.' + m.prop : 'nil'}, mirror: ${isMirror(m)}, frames: [\n`;
    for (const P of framesOf(id)) {
      const main = ORDER.flatMap((k) => P[k]).map(n).join(', ');
      const hasFar = FAR_ORDER.some((k) => P[k]);
      if (hasFar) {
        const far = FAR_ORDER.flatMap((k) => P[k] || [P[k.slice(1)][0] + FAR[0], P[k.slice(1)][1] + FAR[1]]).map(n).join(', ');
        s += `            .j([${main}], far: [${far}]),\n`;
      } else {
        s += `            .j([${main}]),\n`;
      }
    }
    s += '        ])\n';
  }
  s += '        return d\n    }()\n}\n';
  return s;
}

// 預覽用：在畫布上畫道具（和 Swift 的 MoveProp 一樣的位置）
const PROPS = {
  benchFlat: '<rect x="44" y="146" width="96" height="9" rx="3" fill="#3A4452" stroke="#5B6778" stroke-width="1.5"/><rect x="56" y="155" width="6" height="29" fill="#2A313C"/><rect x="122" y="155" width="6" height="29" fill="#2A313C"/>',
  benchBack: '<rect x="20" y="146" width="62" height="9" rx="3" fill="#3A4452" stroke="#5B6778" stroke-width="1.5"/><rect x="30" y="155" width="6" height="29" fill="#2A313C"/><rect x="66" y="155" width="6" height="29" fill="#2A313C"/>',
  benchFront: '<rect x="112" y="146" width="70" height="9" rx="3" fill="#3A4452" stroke="#5B6778" stroke-width="1.5"/><rect x="122" y="155" width="6" height="29" fill="#2A313C"/><rect x="166" y="155" width="6" height="29" fill="#2A313C"/>',
  wall: '<rect x="152" y="20" width="10" height="166" rx="2" fill="#2E3642" stroke="#4A5566" stroke-width="1.5"/>',
};

async function preview(out, only) {
  const { chromium } = require('playwright');
  const ids = only || Object.keys(MOVES);
  const data = {};
  for (const id of ids) {
    const m = MOVES[id];
    const fr = framesOf(id);
    const pick = [0, 0.25, 0.5, 0.75, 1].map((ph) => {
      if (m.loop) {
        const x = ph * fr.length; const i = Math.floor(x) % fr.length; const t = x - Math.floor(x);
        return lerpP(fr[i], fr[(i + 1) % fr.length], t);
      }
      const p = 0.5 - 0.5 * Math.cos(2 * Math.PI * ph * 0.5 * 2); // 0→1→0，取來回
      const x = p * (fr.length - 1); const i = Math.min(Math.floor(x), fr.length - 2); const t = x - i;
      return lerpP(fr[i], fr[i + 1], t);
    });
    data[id] = { title: m.title, gear: m.gear, prop: m.prop ? PROPS[m.prop] : '', poses: pick, mirror: isMirror(m) };
  }
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1000, height: 900 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, '../../docs/character-design.html'));
  await page.evaluate((data) => {
    const basePt = pt;
    window.pt = function (P, j, far) { if (far && P['f' + j]) return P['f' + j]; return basePt(P, j, far); };
    // eslint-disable-next-line no-eval
    (0, eval)('pt = window.pt');
    let src = drawGear.toString().replace('if(POSES[ex].gear==="goblet"){', 'if(POSES[ex].gear==="bare"){}else if(POSES[ex].gear==="goblet"){');
    // 頭跟著脖子轉（和 CharacterCanvas.drawHead 一樣），仰躺翻面
    src = src.replace('  // 頭\n', '  s+=headOpen(P,ex);\n').replace('  // 啞鈴\n', '  s+="</g>";\n');
    window.headOpen = (P, ex) => {
      const d = [P.head[0] - P.sh[0], P.head[1] - P.sh[1]];
      const a = Math.atan2(d[1], d[0]) * 180 / Math.PI + 90;
      const m = POSES[ex].mirror ? ' scale(-1 1)' : '';
      return `<g transform="translate(${P.head[0]} ${P.head[1]}) rotate(${a})${m} translate(${-P.head[0]} ${-P.head[1]})">`;
    };
    (0, eval)(src.replace('function drawGear(', 'window.drawGear=function('));
    const g = { head: 'none', top: 'none', bottom: 'none', feet: 'none', hands: 'none', back: 'none', bell: 'none', fx: 'none' };
    let h = '<div style="background:#0E1116;padding:8px;width:980px;font:13px sans-serif;color:#ccc">';
    for (const id in data) {
      const d = data[id];
      POSES[id] = { muscles: [], gear: d.gear, a: d.poses[0], b: d.poses[0], mirror: d.mirror };
      h += `<div style="display:flex;align-items:center;gap:4px;margin:2px 0"><div style="width:120px">${id}<br>${d.title}</div>`;
      for (const P of d.poses) {
        let svg = '';
        try { svg = drawGear(id, P, g, false, 0.3); } catch (e) { svg = `<text x="40" y="100" fill="red">${e.message}</text>`; }
        h += `<svg width="150" height="170" viewBox="10 -14 180 204" style="background:#161B22;border-radius:8px"><line x1="10" y1="186" x2="190" y2="186" stroke="#333" stroke-width="2"/>${d.prop}${svg}</svg>`;
      }
      h += '</div>';
    }
    document.body.innerHTML = h + '</div>';
    document.body.style.margin = '0';
  }, data);
  await page.setViewportSize({ width: 1000, height: 200 });
  await page.screenshot({ path: out, fullPage: true });
  await b.close();
}

function lerpP(a, b, t) {
  const o = {};
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of keys) {
    const fa = a[k] || [a[k.slice(1)][0] + FAR[0], a[k.slice(1)][1] + FAR[1]];
    const fb = b[k] || [b[k.slice(1)][0] + FAR[0], b[k.slice(1)][1] + FAR[1]];
    o[k] = [fa[0] + (fb[0] - fa[0]) * t, fa[1] + (fb[1] - fa[1]) * t];
  }
  return o;
}

if (require.main === module) {
  const [cmd, out, only] = process.argv.slice(2);
  if (cmd === 'swift') {
    const file = path.join(__dirname, '../../Workout/Character/MoveFrames.swift');
    fs.writeFileSync(file, toSwift());
    console.log('wrote', file);
  } else if (cmd === 'preview') {
    preview(out || 'moves.png', only ? only.split(',') : null);
  } else {
    console.log('用法：node scripts/art/moves.js swift | preview out.png [id,id]');
  }
}

module.exports = { MOVES, fk };
