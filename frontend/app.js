window.addEventListener('error', e => {
  window.__LAST_ERR = { message: e.message, lineno: e.lineno, colno: e.colno, filename: e.filename, error: String(e.error) };
  console.error('App Error:', e);
});

const form = document.querySelector('#watermark-form');
const fields = form.elements;
const save = document.querySelector('#save');
const reveal = document.querySelector('#reveal');
const statusEl = document.querySelector('#status');
const stamps = document.querySelector('#stamps');
const customRangeRow = document.querySelector('#custom-range-row');
const previewDesc = document.querySelector('#preview-desc');

// PDF Dropzone elements
const pdfDropzone = document.querySelector('#pdf-dropzone');
const pdfPrompt = document.querySelector('#pdf-prompt');
const pdfPromptText = document.querySelector('#pdf-prompt-text');
const pdfSelected = document.querySelector('#pdf-selected');
const selectedPdfName = document.querySelector('#selected-pdf-name');
const reselectPdf = document.querySelector('#reselect-pdf');

// Image Dropzone elements
const textSection = document.querySelector('#text-section');
const imageSection = document.querySelector('#image-section');
const imageDropzone = document.querySelector('#image-dropzone');
const imagePrompt = document.querySelector('#image-prompt');
const imagePromptText = document.querySelector('#image-prompt-text');
const imageSelected = document.querySelector('#image-selected');
const selectedImageName = document.querySelector('#selected-image-name');
const imageThumbnail = document.querySelector('#image-thumbnail');
const imagePdfBadge = document.querySelector('#image-pdf-badge');
const reselectImage = document.querySelector('#reselect-image');

const bridge = window.__MoonBit__?.app;

let busy = false;
let sourcePdf = null;
let sourceImage = null;
let imagePreviewUrl = null;
let suppressClickUntil = 0;

function announce(message, error = false) {
  statusEl.textContent = message;
  statusEl.classList.toggle('error', error);
}

function isImageMode() {
  return fields.watermarkType.value === 'image';
}

function updateWatermarkType() {
  const imageMode = isImageMode();
  textSection.hidden = imageMode;
  imageSection.hidden = !imageMode;

  document.querySelectorAll('.text-setting').forEach(el => {
    el.hidden = imageMode;
  });
  document.querySelectorAll('.image-setting').forEach(el => {
    el.hidden = !imageMode;
  });

  if (imageMode) {
    if (fields.opacity.value === '40') {
      fields.opacity.value = '85';
    }
    previewDesc.textContent = '印章 / 图片效果示意';
  } else {
    if (fields.opacity.value === '85') {
      fields.opacity.value = '40';
    }
    previewDesc.textContent = '文字水印效果示意';
  }

  updateModeVisibility();
  updatePreview();
  updateForm();
}

function updateModeVisibility() {
  const centered = fields.style.value === 'centered';
  const isCustomRange = fields.pageRangeMode.value === 'custom';
  const imageMode = isImageMode();

  document.querySelectorAll('.tiled-only').forEach(el => {
    const shouldHide = imageMode || centered;
    el.hidden = shouldHide;
    el.querySelectorAll?.('input')?.forEach(inp => (inp.disabled = shouldHide));
  });

  customRangeRow.hidden = !isCustomRange;
  fields.customRange.disabled = !isCustomRange;
}

function updatePreview() {
  const imageMode = isImageMode();
  const opacity = Math.max(0, Math.min(1, fields.opacity.valueAsNumber / 100 || 0));

  if (!imageMode) {
    const centered = fields.style.value === 'centered';
    const rotate = centered ? 0 : -(fields.rotate.valueAsNumber || 0);
    const count = centered ? 1 : 6;
    const text = fields.text.value.trim() || 'CONFIDENTIAL';
    const color = fields.color.value || '#cc3333';
    const size = fields.textSize.valueAsNumber || 30;

    stamps.dataset.mode = 'text';
    stamps.toggleAttribute('data-centered', centered);
    delete stamps.dataset.pos;

    stamps.replaceChildren(
      ...Array.from({ length: count }, () => {
        const span = document.createElement('span');
        span.textContent = text;
        span.style.color = color;
        span.style.opacity = opacity;
        span.style.fontSize = `${Math.min(26, Math.max(8, size / 4))}px`;
        span.style.rotate = `${rotate}deg`;
        return span;
      }),
    );
  } else {
    const position = fields.imagePosition.value;
    const scalePercent = Math.max(5, Math.min(100, fields.imageScale.valueAsNumber || 35));
    const scaleToFit = fields.scaleToFit.checked;

    stamps.dataset.mode = 'image';
    stamps.dataset.pos = position;
    stamps.removeAttribute('data-centered');

    if (imagePreviewUrl) {
      const img = document.createElement('img');
      img.className = 'stamp-preview-img';
      img.src = imagePreviewUrl;
      img.style.opacity = opacity;
      if (scaleToFit) {
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'contain';
      } else {
        img.style.width = `${scalePercent}%`;
        img.style.height = 'auto';
      }
      if (position === 'diagonal') {
        img.style.transform = 'rotate(-30deg)';
      }
      stamps.replaceChildren(img);
    } else {
      const ph = document.createElement('div');
      ph.className = 'stamp-placeholder';
      ph.textContent = '印章预览';
      ph.style.opacity = opacity;
      stamps.replaceChildren(ph);
    }
  }
}

function updateForm() {
  const imageMode = isImageMode();
  const hasContent = imageMode ? Boolean(sourceImage) : Boolean(fields.text.value.trim());

  save.disabled = busy || !sourcePdf || !hasContent || !form.checkValidity();
  reveal.disabled = busy;
}

function setPdfSource(filePath) {
  if (!filePath) return;
  sourcePdf = filePath;
  const fileName = filePath.split(/[/\\]/).pop();
  selectedPdfName.textContent = fileName;
  selectedPdfName.title = filePath;
  pdfPrompt.hidden = true;
  pdfSelected.hidden = false;
  reveal.hidden = true;
  announce('');
  updateForm();
}

function setImageSource(filePath, previewUrl = null) {
  if (!filePath) return;
  sourceImage = filePath;
  const fileName = filePath.split(/[/\\]/).pop();
  selectedImageName.textContent = fileName;
  selectedImageName.title = filePath;
  const isPdf = fileName.toLowerCase().endsWith('.pdf');
  if (isPdf) {
    imageThumbnail.hidden = true;
    imageThumbnail.removeAttribute('src');
    if (imagePdfBadge) imagePdfBadge.hidden = false;
  } else if (previewUrl) {
    imagePreviewUrl = previewUrl;
    imageThumbnail.src = previewUrl;
    imageThumbnail.hidden = false;
    if (imagePdfBadge) imagePdfBadge.hidden = true;
  } else {
    imagePreviewUrl = null;
    imageThumbnail.hidden = true;
    imageThumbnail.removeAttribute('src');
    if (imagePdfBadge) imagePdfBadge.hidden = true;
  }
  imagePrompt.hidden = true;
  imageSelected.hidden = false;
  announce('');
  updatePreview();
  updateForm();
}

async function handleChoosePdf() {
  if (Date.now() < suppressClickUntil) return;
  if (busy || !bridge?.choosePdf) return;
  busy = true;
  updateForm();
  try {
    const res = await bridge.choosePdf();
    if (res?.path) {
      setPdfSource(res.path);
    }
  } catch {
    announce('打开 PDF 文件失败，请重试。', true);
  } finally {
    busy = false;
    updateForm();
  }
}

async function handleChooseImage() {
  if (Date.now() < suppressClickUntil) return;
  if (busy || !bridge?.chooseImage) return;
  busy = true;
  updateForm();
  try {
    const res = await bridge.chooseImage();
    if (res?.path) {
      setImageSource(res.path, res.preview_data_url);
    }
  } catch {
    announce('文件格式不支持，仅支持 PNG、JPG、JPEG 或 PDF 印章文件。', true);
  } finally {
    busy = false;
    updateForm();
  }
}

function getPageRangeOption() {
  const mode = fields.pageRangeMode.value;
  if (mode === 'all') return 'all';
  if (mode === 'skip-first') return 'skip-first';
  return fields.customRange.value.trim() || 'all';
}

async function tryReveal() {
  try {
    await bridge?.revealPdf();
  } catch {
    announce('PDF 已保存，但无法在文件管理器中显示。', true);
  }
}

// 点击与键盘触发
pdfDropzone.addEventListener('click', e => {
  if (Date.now() < suppressClickUntil) {
    e.preventDefault();
    e.stopPropagation();
    return;
  }
  if (sourcePdf) return; // 已选择文件时，点击整栏不弹出文件框，需点击“更改”
  handleChoosePdf();
});
reselectPdf.addEventListener('click', e => {
  e.stopPropagation();
  handleChoosePdf();
});
pdfDropzone.addEventListener('keydown', e => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    handleChoosePdf();
  }
});

imageDropzone.addEventListener('click', e => {
  if (Date.now() < suppressClickUntil) {
    e.preventDefault();
    e.stopPropagation();
    return;
  }
  if (sourceImage) return; // 已选择图片时，点击整栏不弹出文件框，需点击“更改”
  handleChooseImage();
});
reselectImage.addEventListener('click', e => {
  e.stopPropagation();
  handleChooseImage();
});
imageDropzone.addEventListener('keydown', e => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    handleChooseImage();
  }
});

function readFileAsBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result;
      const base64 = typeof result === 'string' ? result.split(',')[1] : '';
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

async function handleDroppedPdf(file) {
  if (!file || !file.name.toLowerCase().endsWith('.pdf')) {
    announce('文件格式不支持，仅支持 .pdf 文件。', true);
    return;
  }
  announce('正在载入拖入的 PDF 文件……');
  try {
    if (file.path && bridge?.openPdfPath) {
      const res = await bridge.openPdfPath({ path: file.path });
      if (res?.path) {
        setPdfSource(res.path);
        announce(`已载入：${file.name}`);
        return;
      }
    }
    const base64Data = await readFileAsBase64(file);
    if (bridge?.dropPdfData) {
      const res = await bridge.dropPdfData({ name: file.name, data: base64Data });
      if (res?.path) {
        setPdfSource(res.path);
        selectedPdfName.textContent = file.name;
        announce(`已载入：${file.name}`);
      }
    }
  } catch (err) {
    announce(`无法载入拖入的 PDF: ${err?.message || '读取错误'}`, true);
  }
}

async function handleDroppedImage(file) {
  if (!file || !file.name.match(/\.(png|jpe?g|pdf)$/i)) {
    announce('文件格式不支持，仅支持 PNG、JPG、JPEG 或 PDF 印章文件。', true);
    return;
  }
  announce('正在载入水印图片……');
  try {
    if (file.path && bridge?.openImagePath) {
      const res = await bridge.openImagePath({ path: file.path });
      if (res?.path) {
        setImageSource(res.path, res.preview_data_url);
        announce(`已载入印章：${file.name}`);
        return;
      }
    }
    const base64Data = await readFileAsBase64(file);
    if (bridge?.dropImageData) {
      const res = await bridge.dropImageData({ name: file.name, data: base64Data });
      if (res?.path) {
        setImageSource(res.path, res.preview_data_url);
        selectedImageName.textContent = file.name;
        announce(`已载入印章：${file.name}`);
      }
    }
  } catch (err) {
    announce(`无法载入拖入的图片: ${err?.message || '读取错误'}`, true);
  }
}

// PDF 拖拽事件
pdfDropzone.addEventListener('dragover', e => {
  e.preventDefault();
  e.stopPropagation();
  pdfDropzone.classList.add('dragover');
  pdfPromptText.textContent = '松开鼠标添加此 PDF 文件';
});
pdfDropzone.addEventListener('dragleave', e => {
  e.preventDefault();
  e.stopPropagation();
  pdfDropzone.classList.remove('dragover');
  pdfPromptText.textContent = '点击选择 或 拖拽 PDF 文件至此';
});
pdfDropzone.addEventListener('drop', async e => {
  e.preventDefault();
  e.stopPropagation();
  suppressClickUntil = Date.now() + 1000;
  pdfDropzone.classList.remove('dragover');
  pdfPromptText.textContent = '点击选择 或 拖拽 PDF 文件至此';

  const file = e.dataTransfer?.files?.[0];
  if (!file) return;

  if (file.name.toLowerCase().endsWith('.pdf')) {
    await handleDroppedPdf(file);
  } else {
    announce('请拖入有效的 .pdf 文件。', true);
  }
});

// Image 拖拽事件
imageDropzone.addEventListener('dragover', e => {
  e.preventDefault();
  e.stopPropagation();
  imageDropzone.classList.add('dragover');
  imagePromptText.textContent = '松开鼠标添加此印章/图片';
});
imageDropzone.addEventListener('dragleave', e => {
  e.preventDefault();
  e.stopPropagation();
  imageDropzone.classList.remove('dragover');
  imagePromptText.textContent = '点击选择 或 拖拽图片至此 (PNG / JPG / PDF)';
});
imageDropzone.addEventListener('drop', async e => {
  e.preventDefault();
  e.stopPropagation();
  suppressClickUntil = Date.now() + 1000;
  imageDropzone.classList.remove('dragover');
  imagePromptText.textContent = '点击选择 或 拖拽图片至此 (PNG / JPG / PDF)';

  const file = e.dataTransfer?.files?.[0];
  if (!file) return;

  if (file.name.match(/\.(png|jpe?g|pdf)$/i)) {
    await handleDroppedImage(file);
  } else {
    announce('请拖入有效的图片或印章文件 (PNG / JPG / PDF)。', true);
  }
});

// 全窗口拖拽兜底
window.addEventListener('dragover', e => {
  e.preventDefault();
  document.body.classList.add('dragover');
});
window.addEventListener('dragleave', e => {
  if (e.relatedTarget === null) {
    document.body.classList.remove('dragover');
  }
});
window.addEventListener('drop', async e => {
  e.preventDefault();
  suppressClickUntil = Date.now() + 1000;
  document.body.classList.remove('dragover');
  const file = e.dataTransfer?.files?.[0];
  if (!file) return;

  const isPdf = file.name.toLowerCase().endsWith('.pdf');
  const isImage = file.name.match(/\.(png|jpe?g|pdf)$/i);

  if (isPdf) {
    await handleDroppedPdf(file);
  } else if (isImage && isImageMode()) {
    await handleDroppedImage(file);
  }
});

// 表单输入与联动监听
function handleFormChange(event) {
  const name = event?.target?.name;
  if (name === 'imageScaleRange') {
    fields.imageScale.value = fields.imageScaleRange.value;
  } else if (name === 'imageScale') {
    fields.imageScaleRange.value = fields.imageScale.value;
  } else if (name === 'scaleToFit') {
    fields.imageScale.disabled = fields.scaleToFit.checked;
    fields.imageScaleRange.disabled = fields.scaleToFit.checked;
  } else if (name === 'watermarkType') {
    updateWatermarkType();
  } else if (name === 'style' || name === 'pageRangeMode' || name === 'imagePosition') {
    updateModeVisibility();
  }
  updatePreview();
  updateForm();
}

form.addEventListener('input', handleFormChange);
form.addEventListener('change', handleFormChange);

reveal.addEventListener('click', tryReveal);

// 保存执行水印
form.addEventListener('submit', async event => {
  event.preventDefault();
  if (busy || !bridge?.applyWatermarkNative || !sourcePdf) return;

  busy = true;
  updateForm();
  announce('正在处理并保存水印 PDF……');

  const imageMode = isImageMode();
  const pageRange = getPageRangeOption();
  const opacity = (fields.opacity.valueAsNumber || 40) / 100;

  const payload = imageMode
    ? {
        watermark_type: 'image',
        image_path: sourceImage,
        style: fields.imagePosition.value,
        opacity: opacity,
        scale: (fields.imageScale.valueAsNumber || 35) / 100,
        scale_to_fit: fields.scaleToFit.checked,
        page_range: pageRange,
      }
    : {
        watermark_type: 'text',
        text: fields.text.value.trim(),
        font_size: fields.textSize.valueAsNumber || 48,
        style: fields.style.value,
        opacity: opacity,
        rotate: fields.style.value === 'centered' ? 0 : fields.rotate.valueAsNumber || -45,
        color_hex: fields.color.value || '#cc3333',
        page_range: pageRange,
      };

  try {
    const res = await bridge.applyWatermarkNative(payload);
    if (res?.path) {
      announce(`保存成功！已输出至：${res.path}`);
      reveal.hidden = false;
    } else {
      announce('已取消保存。');
    }
  } catch (err) {
    announce(`处理失败: ${err?.message || '未知错误'}`, true);
  } finally {
    busy = false;
    updateForm();
  }
});

// 快捷键支持
window.addEventListener('keydown', event => {
  const isCmdOrCtrl = event.metaKey || event.ctrlKey;
  if (!isCmdOrCtrl) return;
  if (event.key.toLowerCase() === 'o') {
    event.preventDefault();
    handleChoosePdf();
  } else if (event.key.toLowerCase() === 's') {
    event.preventDefault();
    if (!save.disabled) form.requestSubmit();
  }
});

if (!bridge) announce('请在桌面应用中运行。', true);

// 挂载到 window 方便调试与验证
window.__app = {
  updateWatermarkType,
  updatePreview,
  updateForm,
  handleDroppedPdf,
  handleDroppedImage,
  setPdfSource,
  setImageSource
};

// 初始化
try {
  updateWatermarkType();
} catch (e) {
  console.error('Init error:', e);
}
