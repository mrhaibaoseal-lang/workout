// 裝備造型預覽：node scripts/art/gear-preview.js <輸出.png> [系列,系列…]
// 載入 docs/character-design.html 的畫法，換成膚色身體並套上 gear.js 的造型圖層，截圖 12 套 × 3 個動作。
const path = require('path');
const { chromium } = require('playwright');
const { ART } = require('./gear.js');

const out = process.argv[2] || 'gear.png';
const only = process.argv[3] ? process.argv[3].split(',') : null;

const helpers = `
const ART=${JSON.stringify(ART)};
function unit(v){const l=Math.hypot(v[0],v[1])||1;return [v[0]/l,v[1]/l]}
function frame(anchor,P,far,t,goblet){
  const q=(j)=>pt(P,j,far);
  const seg=(a,b,ccw)=>{const x=unit(sub(q(b),q(a)));return {o:q(a),x,y:ccw?[x[1],-x[0]]:[-x[1],x[0]]}};
  switch(anchor){
    case "torso":return seg("hip","sh",false);
    case "nape":{const x=unit(sub(q("sh"),q("hip")));const a=Math.sin(t*2.2)*3*Math.PI/180;
      const xr=[x[0]*Math.cos(a)-x[1]*Math.sin(a),x[0]*Math.sin(a)+x[1]*Math.cos(a)];return {o:q("sh"),x:xr,y:[-xr[1],xr[0]]}}
    case "thigh":return seg("hip","kn",true);
    case "shin":return seg("kn","an",true);
    case "foot":return seg("an","to",true);
    case "upper":return seg("sh","el",true);
    case "fore":return seg("el","ha",true);
    case "fist":{const x=unit(sub(q("ha"),q("el")));return {o:q("ha"),x,y:[x[1],-x[0]]}}
    case "grip":return goblet?{o:q("ha"),x:[0,-1],y:[-1,0]}:{o:q("ha"),x:[1,0],y:[0,-1]};
  }
}
let GID=0;
function layersSVG(layers,fr,dim){
  const m=\`matrix(\${fr.x[0]} \${fr.x[1]} \${fr.y[0]} \${fr.y[1]} \${fr.o[0]} \${fr.o[1]})\`;
  let s="",defs="";
  for(const l of layers){let fill;
    if(l.fill[0]==="solid")fill=\`fill="\${l.fill[1]}" fill-opacity="\${l.fill[2]}"\`;
    else{const id="lg"+(GID++);const n=l.fill[1].length;defs+=\`<linearGradient id="\${id}" x1="0" y1="0" x2="0" y2="1" gradientUnits="objectBoundingBox">\${l.fill[1].map((h,i)=>\`<stop offset="\${n===1?0:i/(n-1)}" stop-color="\${h}"/>\`).join("")}</linearGradient>\`;fill=\`fill="url(#\${id})"\`}
    const st=l.stroke?\`stroke="\${l.stroke}" stroke-width="\${l.sw}" stroke-linejoin="round" stroke-linecap="round"\`:"";
    s+=\`<path d="\${l.d}" \${fill} \${st} \${l.blur?'filter="url(#gblur2)"':""}/>\`}
  return \`<defs>\${defs}</defs><g transform="\${m}" \${dim?'style="filter:brightness(.72)"':""}>\${s}</g>\`;
}
function partsFor(g,z,anchorFilter,P,t,ex,farOnly){
  let s="";
  for(const [slot] of SLOTS){const id=g[slot];
    let key=id&&id!=="none"?id+"."+slot:null;
    if(slot==="bell"&&!key)key="default.bell";
    if(slot==="bell"&&POSES[ex].gear==="bare")continue;
    const ps=key&&ART[key];if(!ps)continue;
    for(const p of ps){if(p.z!==z)continue;if(anchorFilter&&!anchorFilter(p.anchor))continue;
      const goblet=POSES[ex].gear==="goblet";
      if(p.far&&!(slot==="bell"&&goblet)&&(farOnly!==false))s+=layersSVG(p.layers,frame(p.anchor,P,true,t,goblet),true);
      if(farOnly!==true)s+=layersSVG(p.layers,frame(p.anchor,P,false,t,goblet),false);}
  }
  return s;
}
`;

(async () => {
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1300, height: 900 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, '../../docs/character-design.html'));
  const src = await page.evaluate(() => [...document.scripts].map((s) => s.textContent).join('\n'));
  const start = src.indexOf('function drawGear(');
  const end = src.indexOf('function rarDot(');
  let fn = src.slice(start, end);
  const rep = (a, b2) => { if (!fn.includes(a)) throw new Error('patch miss: ' + a.slice(0, 60)); fn = fn.replace(a, b2); };
  rep('(base==="neck"?"var(--skin)":far?"var(--grey)":"var(--grey-sticker)")', '(base==="neck"?"#E9BE9C":far?"#BF8F6C":"#E3B48F")');
  rep('if(bk.form==="ring")', 'if(false)');
  rep('if(bk.form==="cape")s+=cape(P,bk,t);', 's+=partsFor(g,"back",null,P,t,ex);');
  rep('if(bk.form==="sword")', 'if(false)');
  rep('if(bk.form==="wings")', 'if(false)');
  rep('if(bk.form==="jets")', 'if(false)');
  rep('\n  }\n  for(const sh of shapes)if(sh.t==="line"&&!sh.far&&sh.w>=11)',
    '\n  {const an=sh.t==="torso"?"torso":sh.base;s+=partsFor(g,"limb",(a)=>a===an||(an==="fore"&&a==="fist"),P,t,ex,sh.far===true);}}\n  for(const sh of shapes)if(sh.t==="line"&&!sh.far&&sh.w>=11)');
  rep('if(hn.form){', 'if(false){');
  rep('  // 頭\n', '  s+=partsFor(g,"over",null,P,t,ex);\n  // 頭\n');
  rep('if(POSES[ex].gear==="goblet"){const r=', 's+=partsFor(g,"grip",null,P,t,ex);if(false){const r=');
  rep('else{for(const [p,rad] of [[hf,8],[h,9]])', 'else if(false){for(const [p,rad] of [[hf,8],[h,9]])');
  await page.evaluate(({ helpers, fn, only }) => {
    // eslint-disable-next-line no-eval
    window.SZ=only?260:130;(0, eval)(helpers + fn.replace('function drawGear(', 'window.drawGear2=function('));
    const poses = [['squat', 0.5], ['press', 1], ['rdl', 0.7]];
    let h = '<div style="background:#0E1116;padding:8px;display:flex;flex-wrap:wrap;gap:6px;width:1280px">';
    for (const se of SERIES) {
      if (only && !only.includes(se.id)) continue;
      h += `<div style="background:#161B22;border-radius:10px;padding:4px;color:#ccc;font:12px sans-serif;text-align:center">${se.name}<br>`;
      for (const [ex, tt] of poses) h += `<svg width="${window.SZ||130}" height="${Math.round((window.SZ||130)*1.277)}" viewBox="30 -14 160 204">${window.drawGear2(ex, pose(ex, tt), fullSet(se.id), false, 0.3)}</svg>`;
      h += '</div>';
    }
    document.body.innerHTML = h;
    document.body.style.margin = '0';
  }, { helpers, fn, only });
  await page.setViewportSize({ width: 1300, height: 200 });
  await page.screenshot({ path: out, fullPage: true });
  await b.close();
})();
