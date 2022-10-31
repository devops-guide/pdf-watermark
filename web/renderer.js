const { createApp } = Vue

const vueApp = createApp({
  data() {
      return {
          inputFilePath: '',
          textOptions: {
              text: '',
              opacity: 0.4,
              rotate: -45,
          }
      }
  },
  methods: {
      async choiceFile () {
        const filePath = await window.electronAPI.choiceFile()
        this.inputFilePath = filePath;
      },
      async saveFile () {
        window.electronAPI.saveFile({ ... this.textOptions});
      }
  }
});

vueApp.mount('#app');