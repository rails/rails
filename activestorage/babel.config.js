module.exports = (api) => {
  api.cache(true);
  return {
    presets: [
      [
        "@babel/preset-env",
        {
          modules: false
        },
      ],
    ],
    plugins: ["@babel/plugin-external-helpers"]
  };
};
