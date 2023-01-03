// Karma configuration for running the UJS tests

const config = {
  browsers: ["ChromeHeadless"],
  frameworks: ["qunit"],
  files: [
    "test/ujs/compiled/test.js",
  ],

  client: {
    clearContext: false,
    qunit: {
      showUI: true
    }
  },

  singleRun: true,
  autoWatch: false,

  captureTimeout: 180000,
  browserDisconnectTimeout: 180000,
  browserDisconnectTolerance: 3,
  browserNoActivityTimeout: 300000,
  proxies: {
    '/echo': 'http://localhost:4567/echo',
    '/error': 'http://localhost:4567/error'
  }
}

if (process.env.CI) {
  config.customLaunchers = {
    sl_chrome: sauce("chrome", "latest", "Windows 10")
  }

  config.browsers = Object.keys(config.customLaunchers)
  config.reporters = ["dots", "saucelabs"]

  config.sauceLabs = {
    testName: "Rails UJS",
    retryLimit: 3,
    build: buildId(),
  }

  function sauce(browserName, version, platform) {
    const options = {
      base: "SauceLabs",
      browserName: browserName.toString(),
      version: version.toString(),
    }
    if (platform) {
      options.platform = platform.toString()
    }
    return options
  }

  function buildId() {
    const { BUILDKITE_JOB_ID } = process.env
    return BUILDKITE_JOB_ID
      ? `Buildkite ${BUILDKITE_JOB_ID}`
      : ""
  }
}

module.exports = function(karmaConfig) {
  karmaConfig.set(config)
}
