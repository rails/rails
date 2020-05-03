module.exports = (api) => {
  api.cache(true);
  return {
    presets: [
      [
        '@babel/preset-env',
        {
          modules: false,
          loose: true
        },
      ],
    ],
    plugins: ["@babel/plugin-external-helpers"]
  };
};
