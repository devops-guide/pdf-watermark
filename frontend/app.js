const form = document.querySelector('#watermark-form');
const fields = form.elements;
const choose = document.querySelector('#choose');
const save = document.querySelector('#save');
const reveal = document.querySelector('#reveal');
const fileName = document.querySelector('#file-name');
const status = document.querySelector('#status');
const stamps = document.querySelector('#stamps');
const bridge = window.__MoonBit__?.app;
const chunkSize = 512 * 1024;

let busy = false;
let source;
let worker;

function announce(message, error = false) {
  status.textContent = message;
  status.classList.toggle('error', error);
}

function updateForm() {
  choose.disabled = busy || !bridge;
  save.disabled = busy || !source || !fields.text.value.trim() || !form.checkValidity();
  reveal.disabled = busy;
}

function updatePreview() {
  const centered = fields.style.value === 'centered';
  const text = fields.text.value.trim() || '水印文字';
  const opacity = Math.max(0, Math.min(1, fields.opacity.valueAsNumber / 100 || 0));
  const size = fields.textSize.valueAsNumber || 30;
  const count = centered ? 1 : 6;
  stamps.toggleAttribute('data-centered', centered);
  stamps.replaceChildren(...Array.from({ length: count }, () => {
    const stamp = document.createElement('span');
    stamp.textContent = text;
    stamp.style.opacity = opacity;
    stamp.style.fontSize = `${Math.min(32, Math.max(9, size / 4))}px`;
    stamp.style.rotate = `${centered ? 0 : -(fields.rotate.valueAsNumber || 0)}deg`;
    return stamp;
  }));
}

function setMode() {
  const centered = fields.style.value === 'centered';
  fields.textSize.value = centered ? 150 : 30;
  fields.rotate.value = centered ? 0 : -45;
  fields.marginRight.value = centered ? 50 : 150;
  fields.marginBottom.value = centered ? 50 : 150;
  document.querySelectorAll('.tiled-only').forEach(label => {
    label.hidden = centered;
    label.querySelector('input').disabled = centered;
  });
}

async function readPdf() {
  const chunks = [];
  let offset = 0;
  let done;
  do {
    const reply = await bridge.readPdf({ offset: String(offset) });
    chunks.push(Uint8Array.fromBase64(reply.data));
    offset = Number(reply.next_offset);
    done = reply.done;
  } while (!done);
  const bytes = new Uint8Array(offset);
  let position = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, position);
    position += chunk.length;
  }
  return bytes;
}

function applyWatermark(pdf, options) {
  worker ??= new Worker('watermark-worker.js');
  return new Promise((resolve, reject) => {
    worker.onmessage = ({ data }) => {
      if (data.error) reject(new Error(data.error));
      else resolve(data.bytes);
    };
    worker.onerror = () => {
      worker.terminate();
      worker = undefined;
      reject(new Error('无法启动 PDF 处理。'));
    };
    worker.postMessage({ pdf, options }, [pdf.buffer]);
  });
}

async function tryReveal() {
  try {
    await bridge.revealPdf();
  } catch {
    announce('PDF 已保存，但无法在文件管理器中显示。', true);
  }
}

form.addEventListener('input', event => {
  if (event.target.name === 'style') setMode();
  updatePreview();
  updateForm();
});

choose.addEventListener('click', async () => {
  busy = true;
  updateForm();
  try {
    const { path } = await bridge.choosePdf();
    if (path) {
      source = path;
      fileName.value = path.split(/[/\\]/).pop();
      fileName.title = path;
      reveal.hidden = true;
      announce('');
    }
  } catch {
    announce('无法选择文件。请检查它是否为可读取的 PDF。', true);
  } finally {
    busy = false;
    updateForm();
  }
});

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (busy || !source || !form.reportValidity()) return;
  const options = {
    style: fields.style.value,
    text: fields.text.value,
    textSize: fields.textSize.valueAsNumber,
    opacity: fields.opacity.valueAsNumber / 100,
    rotate: fields.rotate.valueAsNumber,
    marginRight: fields.marginRight.valueAsNumber,
    marginBottom: fields.marginBottom.valueAsNumber,
  };
  busy = true;
  updateForm();
  let exportStarted = false;
  let errorMessage = '无法保存 PDF。请检查目标位置和写入权限。';
  try {
    const decision = await bridge.beginExport();
    if (decision === 'cancelled') return;
    if (decision === 'source') {
      announce('请选择与源 PDF 不同的保存位置。', true);
      return;
    }

    exportStarted = true;
    reveal.hidden = true;
    announce('正在处理 PDF…');
    errorMessage = '无法处理 PDF。请检查文件是否完整、是否加密，以及水印参数是否有效。';
    const output = await applyWatermark(await readPdf(), options);

    errorMessage = '无法保存 PDF。请检查目标位置和写入权限。';
    let destination;
    for (let offset = 0; offset < output.length; offset += chunkSize) {
      ({ path: destination } = await bridge.writePdf({
        data: output.subarray(offset, offset + chunkSize).toBase64(),
        final_chunk: offset + chunkSize >= output.length,
      }));
    }
    exportStarted = false;
    reveal.hidden = false;
    announce(`已保存 ${destination.split(/[/\\]/).pop()}`);
    await tryReveal();
  } catch {
    announce(errorMessage, true);
  } finally {
    if (exportStarted) await bridge.discardExport().catch(() => {});
    busy = false;
    updateForm();
  }
});

reveal.addEventListener('click', tryReveal);
if (!bridge) announce('请在 PDF 水印桌面应用中打开此页面。', true);
updatePreview();
updateForm();
