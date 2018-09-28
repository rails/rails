// See https://karma-runner.github.io/2.0/config/configuration-file.html
// and https://github.com/jlmakes/karma-rollup-preprocessor

resolve = require("rollup-plugin-node-resolve") // https://github.com/rollup/rollup-plugin-node-resolve/
commonjs = require("rollup-plugin-commonjs")
babel = require("rollup-plugin-babel")          // https://github.com/rollup/rollup-plugin-babel#configuring-babel

module.exports = function(config) {
  config.set({
    browsers: [
      'PhantomJS',
    ],
    files: [
      { pattern: 'app/javascript/actioncable/**/*.js', included: false },
      { pattern: 'test/javascript/src/unit/*.js', included: false },

      'test/javascript/src/test.js',
    ],
    frameworks: [
      'qunit', 
      'requirejs',
    ],
    plugins: [
      'karma-phantomjs-launcher',
      'karma-qunit',
      'karma-requirejs',
      'karma-rollup-preprocessor',
    ],
    preprocessors: {
      'app/javascript/actioncable/index.js': ['rollup'],
      'test/javascript/src/**/*.js': ['rollup'],
    },
    rollupPreprocessor: {
      plugins: [
        resolve(),
        commonjs(),
        babel(),
      ],
      output: {
        format: "iife",
        name: "ActionCable",
        sourcemap: 'inline',
      },
    },
    // logLevel: config.LOG_DEBUG
  });
};
