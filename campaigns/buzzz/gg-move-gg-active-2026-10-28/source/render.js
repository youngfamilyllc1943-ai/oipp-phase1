const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
 for (const p of ['move','active']) for (const [f,w,h] of [['feed',1080,1350],['story',1080,1920],['wide',1200,628]]) {
  const pg=await b.newPage({viewport:{width:w,height:h},deviceScaleFactor:1});
  await pg.goto(`file://${__dirname}/card.html?p=${p}&f=${f}`); await pg.waitForSelector('body[data-ready]'); await pg.waitForTimeout(300);
  const out=`out/GG-${p.toUpperCase()}_BUZZZ_${f}_${w}x${h}.png`; await pg.screenshot({path:out}); console.log(out); await pg.close(); }
 await b.close();})();
