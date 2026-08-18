// 元のアプリからデータと正解値を吐き出す。Swift 側はこれと突き合わせる。
const fs=require("fs");
const js=fs.readFileSync("/Users/shimizukento/Documents/ハッカソン/index.html","utf8")
  .split("<script>")[1].split("</script>")[0];
const line=n=>{const i=js.indexOf("var "+n+" = ");const j=js.indexOf("\n",i);return js.slice(i, js.lastIndexOf(";",j)+1);};
const between=(a,b)=>js.slice(js.indexOf(a), js.indexOf(b));
const obj=n=>{const i=js.indexOf("var "+n+" = {");return js.slice(i, js.indexOf("\n};", i)+3);};
const src=["var R_EARTH=6371000;",obj("CONFIG"),
  between("var PHOTOS = {","var SPOTS = ["),
  line("SPOTS"),line("CULTURE"),line("STATIONS"),line("OD_MESH"),line("NAME_EN"),line("STATION_EN"),
  (()=>{const i=js.indexOf("var LANDMARKS = [");return js.slice(i, js.indexOf("\n];", i)+3);})(),
  between("var MESH_LO = 0","var Crowd = {"),
  obj("OPEN_HOURS"),
  between("function rad(","function dirIndex"),
  between("var Crowd = {","var CATEGORIES = {"),
  between("function isOpen(","function closedKinds"),
  between("var SpotSource = {","/* 生きているデータベース"),
  between("var Draw = {","/* 伏せた一行"),
  between("var DIRS = [","function openThrough"),
].join("\n");
const g={};
new Function("g",src+`;g.SPOTS=SPOTS;g.CULTURE=CULTURE;g.STATIONS=STATIONS;g.OD_MESH=OD_MESH;
 g.NAME_EN=NAME_EN;g.STATION_EN=STATION_EN;g.OPEN_HOURS=OPEN_HOURS;g.CONFIG=CONFIG;g.MESH_LO=MESH_LO;g.MESH_HI=MESH_HI;
 g.distanceM=distanceM;g.bearingDeg=bearingDeg;g.Crowd=Crowd;g.Draw=Draw;g.Route=Route;
 g.SpotSource=SpotSource;g.isOpen=isOpen;g.LANDMARKS=LANDMARKS;`)(g);

const R="Sources/SozoroCore/Resources/";
const W=(n,o)=>fs.writeFileSync(R+n, JSON.stringify(o));
W("spots.json", g.SPOTS.map(r=>({name:r[0],lat:r[1],lon:r[2],kind:r[3],category:r[4]})));
W("culture.json", g.CULTURE.map(r=>({name:r[0],lat:r[1],lon:r[2],category:r[3]})));
W("stations.json", g.STATIONS.map(r=>({name:r[0],lat:r[1],lon:r[2]})));
W("mesh.json", g.OD_MESH.map(r=>({lat:r[0],lon:r[1],weekend:r[2],weekday:r[3]})));
W("names.json", {spots:g.NAME_EN, stations:g.STATION_EN});
// 基準地点もウェブ版から吐く。両方で別々に持つと、種類や集客力が静かにずれる。
W("landmarks.json", g.LANDMARKS);

// ── 正解値 ──────────────────────────────────────────────
const P=[[35.7138,139.7772],[35.7108,139.7967],[35.7276,139.7663],[35.7039,139.7897],[35.7255,139.7860]];
const golden={config:g.CONFIG, meshLo:g.MESH_LO, meshHi:g.MESH_HI, geo:[], footfall:[], crowd:[], weight:[], routes:[]};
for(let i=0;i<P.length;i++) for(let j=0;j<P.length;j++){
  if(i===j) continue;
  const a={lat:P[i][0],lon:P[i][1]}, b={lat:P[j][0],lon:P[j][1]};
  golden.geo.push({a:P[i],b:P[j],distance:g.distanceM(a,b),bearing:g.bearingDeg(a,b)});
}
for(const p of P) for(const we of [true,false])
  golden.footfall.push({at:p,weekend:we,value:g.Crowd.footfall({lat:p[0],lon:p[1]},we)});
const when=new Date(2026,7,18,14,0,0);          // 2026-08-18 14:00 火曜
const spots=g.SpotSource.build();
for(const idx of [0,10,40,80,120,155]){
  const s=spots[idx];
  golden.crowd.push({name:s.name,kind:s.kind,pop:s.pop,lat:s.lat,lon:s.lon,
                     at:"2026-08-18T14:00", value:g.Crowd.at(s,when)});
}
const origin={lat:35.7138,lon:139.7772};
const t=g.Draw.targetMetres(g.CONFIG.LEG_MIN), tol=g.Draw.tolMetres();
const ctx={origin,target:t,tol,max:t+tol*2.4,moods:["food","culture"],avoid:true,visited:new Set(),now:when,cores:g.Crowd.cores(when)};
for(const idx of [0,10,40,80,120,155]){
  const s=spots[idx];
  golden.weight.push({name:s.name,value:g.Draw.weight(s,ctx)});
}
golden.band={target:t,tol:tol,max:ctx.max};
// 母集団ぜんぶ × 4つの時刻。抜き取りだと、直した所だけ合っていて他がずれる事故を拾えない。
// 基準地点21件の混雑。集客力とかたちを手で置いてあるので、行き先とは別に見る。
golden.landmarks=[];
{
  for(const h of [2,11,14,19]) for(const m of g.LANDMARKS)
    golden.landmarks.push({id:m.id, hour:h, value:g.Crowd.at(m, new Date(2026,7,16,h,0,0))});
}
golden.weightAll={};
for(const h of [2,11,14,19]){
  const w=new Date(2026,7,18,h,0,0);
  const c={origin,target:t,tol,max:ctx.max,moods:["food","culture"],avoid:true,visited:new Set(),now:w,cores:g.Crowd.cores(w)};
  golden.weightAll["h"+String(h).padStart(2,"0")]=spots.map(s=>g.Draw.weight(s,c));
}
// 深夜。飲食が閉まり、寺社と公園だけが残る時間帯の重み。
const night=new Date(2026,7,18,2,0,0);
const nctx={origin,target:t,tol,max:ctx.max,moods:["food","culture"],avoid:true,visited:new Set(),now:night,cores:g.Crowd.cores(night)};
golden.weightNight=[];
for(const idx of [0,10,40,80,120,155]){
  const s=spots[idx];
  golden.weightNight.push({name:s.name,kind:s.kind,value:g.Draw.weight(s,nctx)});
}
for(const p of P){
  const o={lat:p[0],lon:p[1]};
  const opts=g.Route.stationsFrom(o);
  golden.routes.push({origin:p, options:opts.map(x=>({dir:x.dir.k,station:x.st.name,mins:x.mins,
    stops:g.Route.build(o,x).stops.map(s=>s.name)}))});
}
fs.writeFileSync("Tests/SozoroCoreTests/golden.json", JSON.stringify(golden,null,1));
console.log("データ:", g.SPOTS.length,"spots /",g.CULTURE.length,"culture /",g.STATIONS.length,"stations /",g.OD_MESH.length,"mesh");
console.log("正解値: geo",golden.geo.length,"footfall",golden.footfall.length,"crowd",golden.crowd.length,
            "weight",golden.weight.length,"routes",golden.routes.reduce((a,r)=>a+r.options.length,0));
