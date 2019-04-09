const config = {
  browsers: ["ChromeHeadless"],
  frameworks: ["qunit"],
  files: [
    "test/javascript/compiled/test.js",
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
}

if (process.env.CI) {
  config.customLaunchers = {
    sl_chrome: sauce("chrome", 70),
    sl_ff: sauce("firefox", 63),
    sl_safari: sauce("safari", 12.0, "macOS 10.13"),
    sl_edge: sauce("microsoftedge", 17.17134, "Windows 10"),
    sl_ie_11: sauce("internet explorer", 11, "Windows 8.1"),
  }

  config.browsers = Object.keys(config.customLaunchers)
  config.reporters = ["dots", "saucelabs"]

  config.sauceLabs = {
    testName: "ActionCable JS Client",
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
