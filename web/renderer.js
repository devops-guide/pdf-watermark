const choiceBtn = document.getElementById('choice-file');

choiceBtn.addEventListener('click', async (event) => {
  const filePath = await window.electronAPI.choiceFile()
  console.log(filePath);
});

const saveBtn = document.getElementById('save-file');
const watermarkTextInput = document.getElementById('watermarkText');

saveBtn.addEventListener('click', async () => {
  await window.electronAPI.saveFile(watermarkTextInput.value);
})
