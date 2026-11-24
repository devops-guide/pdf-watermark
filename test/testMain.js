const assert = require('node:assert/strict');
const { mkdtemp, readFile, rm, writeFile } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { PDFDocument, PDFArray } = require('pdf-lib');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const { addWatermark } = require('../main');
const { watermarkPdf } = require('../watermark');

const input = path.join(__dirname, 'input.pdf');
const font = readFile(path.join(__dirname, '../fonts/Microsoft Yahei.ttf'));

test('applies centered and tiled watermarks on every page', async () => {
  const source = await PDFDocument.create();
  source.addPage([400, 500]);
  source.addPage([640, 420]);
  const pdf = await source.save();

  for (const style of ['centered', 'tiled']) {
    const bytes = await watermarkPdf(pdf, await font, {
      style,
      text: '仅供内部使用',
      textSize: 30,
      opacity: 0.4,
    });
    const pages = (await PDFDocument.load(bytes)).getPages();
    assert.deepEqual(pages.map(page => page.getSize()), [
      { width: 400, height: 500 },
      { width: 640, height: 420 },
    ]);
    for (const page of pages) {
      assert.ok(page.node.Contents() instanceof PDFArray);
      assert.ok(page.node.Resources().keys().some(key => key.asString() === '/Font'));
    }
  }

  await assert.rejects(watermarkPdf(pdf, await font, {
    style: 'tiled', text: '无效尺寸', textSize: 0,
  }), /水印参数无效/);
});

test('file API and existing MCP tool export the original fixture', async t => {
  const dir = await mkdtemp(path.join(tmpdir(), 'pdf-watermark-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const source = path.join(dir, '原始文件.pdf');
  const original = await readFile(input);
  await writeFile(source, original);
  const standalone = path.join(dir, 'standalone.pdf');
  await addWatermark(source, standalone, { style: 'tiled', text: '独立测试' });

  const client = new Client({ name: 'pdf-watermark-test', version: '1.0.0' });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [path.resolve(__dirname, '../mcp-server.js')],
    stderr: 'pipe',
  });
  t.after(() => client.close());
  await client.connect(transport);
  const reply = await client.callTool({ name: 'pdf', arguments: { filepath: source, text: '内部测试' } });
  const exported = path.join(dir, '原始文件-watermark.pdf');
  assert.equal(reply.isError, undefined);
  assert.deepEqual(reply.content, [{ type: 'text', text: exported }]);
  assert.deepEqual(await readFile(source), original);

  const count = (await PDFDocument.load(original)).getPageCount();
  for (const result of [standalone, exported]) {
    assert.equal((await PDFDocument.load(await readFile(result))).getPageCount(), count);
  }
});
