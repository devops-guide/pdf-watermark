const { createApp } = Vue

const vueApp = createApp({
  data() {
      return {
          inputFilePath: '',
          textOptions: {
              text: '',
          }
      }
  },
  methods: {
      async choiceFile () {
        const filePath = await window.electronAPI.choiceFile()
        this.inputFilePath = filePath;
      },
      async saveFile () {
        window.electronAPI.saveFile(this.textOptions.text);
      }
  }
});

vueApp.mount('#app');