module.exports = {
  packagerConfig: {
    icon: 'icons/logo.ico',
  },
  makers: [
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'pdf_watermark',
      },
    },
    {
      name: '@electron-forge/maker-zip',
      platforms: [
        'darwin',
      ],
    },
    {
      name: '@electron-forge/maker-dmg',
      platforms: ['darwin'],
      config: {
        background: './icons/logo.png',
        format: 'ULFO',
      },
    },
    {
      name: '@electron-forge/maker-deb',
      config: {},
    },
    {
      name: '@electron-forge/maker-rpm',
      config: {},
    },
  ],
  publishers: [
    {
      name: '@electron-forge/publisher-github',
      config: {
        repository: {
          owner: 'xbl',
          name: 'PW',
        },
        prerelease: true,
      },
    },
  ],
};
