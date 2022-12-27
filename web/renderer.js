/* eslint-disable-next-line no-undef */
const { createApp } = Vue;

const vueApp = createApp({
  data() {
    return {
      loading: false,
      showTip: false,
      textOptions: {
        inputFilePath: '',
        text: '',
        textSize: 30,
        opacity: 0.4,
        rotate: -45,
        marginRight: 150,
        marginBottom: 150,
        style: 'tiled',
      },
    };
  },
  watch: {
    'textOptions.style': function (newVal) {
      if (newVal === 'centered') {
        this.textOptions.rotate = 0;
        this.textOptions.textSize = 150;
        this.textOptions.marginRight = 50;
        this.textOptions.marginBottom = 50;
      } else {
        this.textOptions.rotate = -45;
        this.textOptions.textSize = 30;
        this.textOptions.marginRight = 150;
        this.textOptions.marginBottom = 150;
      }
    },
  },
  methods: {
    async choiceFile() {
      const filePath = await window.electronAPI.choiceFile();
      this.textOptions.inputFilePath = filePath;
    },
    async saveFile() {
      this.loading = true;
      const filePath = await window.electronAPI.saveFile({ ...this.textOptions });
      this.loading = false;
      if (filePath) {
        this.showTip = true;
        await window.electronAPI.openFolder(filePath);
        setTimeout(() => {
          this.showTip = false;
        }, 3000);
      }
    },
  },
});

vueApp.mount('#app');
