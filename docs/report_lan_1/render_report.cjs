const fs = require('fs');
const path = require('path');
const {pathToFileURL} = require('url');
const {chromium} = require('C:/Users/Minh Phat/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');

(async () => {
  const root = __dirname;
  const qa = path.join(root, 'qa');
  fs.mkdirSync(qa, {recursive: true});
  const browser = await chromium.launch({
    executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    headless: true,
  });
  try {
    const page = await browser.newPage({viewport: {width: 1360, height: 1000}});
    await page.goto(pathToFileURL(path.join(root, 'BAO_CAO.html')).href);
    await page.evaluate(async () => {
      await document.fonts.ready;
      await Promise.all([...document.images].map(i => i.complete ? null : new Promise(resolve => {
        i.onload = resolve; i.onerror = resolve;
      })));
    });
    const brokenImages = await page.locator('img').evaluateAll(nodes => nodes.filter(i => !i.complete || !i.naturalWidth).map(i => i.src));
    if (brokenImages.length) throw Error('Broken report images: ' + brokenImages.join(','));
    await page.screenshot({path: path.join(qa, 'report-first-screen.png')});
    await page.pdf({
      path: path.join(root, 'BAO_CAO.pdf'),
      preferCSSPageSize: true,
      printBackground: true,
      displayHeaderFooter: true,
      headerTemplate: '<div style="font:8px Arial;width:100%;text-align:center;color:#52635c">SPORTMATCH • PHÂN TÍCH THIẾT KẾ • LẦN 1</div>',
      footerTemplate: '<div style="font:8px Arial;width:100%;text-align:center;color:#52635c">10/10/2026 • <span class="pageNumber"></span> / <span class="totalPages"></span></div>',
    });
    for (const {code} of JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8')).diagrams) {
      const svg = fs.readFileSync(path.join(root, 'diagrams', code + '.svg'), 'utf8');
      const size = {width: Number(svg.match(/width="(\d+)"/)[1]), height: Number(svg.match(/height="(\d+)"/)[1])};
      await page.setContent('<!doctype html><html><meta charset="utf-8"><style>body{margin:0}</style><body>' + svg + '</body></html>');
      await page.setViewportSize(size);
      await page.screenshot({path: path.join(qa, code + '.png'), fullPage: true, timeout: 60000});
    }
    await page.setViewportSize({width: 390, height: 844});
    await page.goto(pathToFileURL(path.join(root, 'index.html')).href);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
    fs.writeFileSync(path.join(qa, 'render_results.json'), JSON.stringify({brokenImages, indexMobileOverflow: overflow}, null, 2));
    console.log('PDF and diagram previews rendered. Mobile index overflow: ' + overflow);
  } finally {
    await browser.close();
  }
})().catch(e => {console.error(e); process.exitCode = 1;});
