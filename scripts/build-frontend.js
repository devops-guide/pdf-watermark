const { cp, mkdir } = require('node:fs/promises');
const { build } = require('esbuild');

async function main() {
  const output = 'frontend/dist';
  await mkdir(output, { recursive: true });
  await Promise.all([
    build({
      entryPoints: ['frontend/watermark-worker.js'],
      outfile: `${output}/watermark-worker.js`,
      bundle: true,
      minify: true,
      target: 'chrome120',
    }),
    ...['index.html', 'style.css', 'app.js'].map(file =>
      cp(`frontend/${file}`, `${output}/${file}`)),
    cp('fonts/Microsoft Yahei.ttf', `${output}/watermark.ttf`),
  ]);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
