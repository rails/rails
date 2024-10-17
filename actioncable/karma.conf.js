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

  concurrency: 4,
  captureTimeout: 60000,
  browserDisconnectTimeout: 120000,
  browserDisconnectTolerance: 5,
  browserNoActivityTimeout: 120000,
  retryLimit: 5,
}

if (process.env.CI) {
  config.customLaunchers = {
    sl_chrome: { base: "SauceLabs", browserName: "chrome", version: "latest" },
    sl_ff: {
      base: "SauceLabs",
      browserName: "firefox",
      browserVersion: "latest",
      "moz:debuggerAddress": true
    },
    sl_safari: {
      base: "SauceLabs",
      browserName: "safari",
      version: "12.1",
      platform: "macOS 10.13"
    },
    sl_edge: {
      base: "SauceLabs",
      browserName: "microsoftedge",
      version: "latest",
      platform: "Windows 10",
      chromeOptions: {
        args: ['--no-sandbox', '--disable-dev-shm-usage']
      }
    }
  }

  config.browsers = Object.keys(config.customLaunchers)
  config.reporters = ["dots", "saucelabs"]

  config.sauceLabs = {
    testName: "ActionCable JS Client",
    idleTimeout: 90,
    commandTimeout: 90,
    maxDuration: 300,
    avoidProxy: true,
    startConnect: true,
    username: process.env.SAUCE_USERNAME,
    accessKey: process.env.SAUCE_ACCESS_KEY,
    build: buildId(),
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
