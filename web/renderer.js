/* eslint-disable-next-line no-undef */
const { createApp } = Vue;

const vueApp = createApp({
  data() {
    return {
      inputFilePath: '',
      loading: false,
      textOptions: {
        text: '',
        opacity: 0.4,
        rotate: -45,
      },
    };
  },
  methods: {
    async choiceFile() {
      const filePath = await window.electronAPI.choiceFile();
      this.inputFilePath = filePath;
    },
    async saveFile() {
      this.loading = true;
      await window.electronAPI.saveFile({ ...this.textOptions });
      this.loading = false;
    },
  },
});

vueApp.mount('#app');
