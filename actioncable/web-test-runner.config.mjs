/* global process */

import { createSauceLabsLauncher } from "@web/test-runner-saucelabs"
import { createRequire } from "module"

const require = createRequire(`${process.cwd()}/web-test-runner.config.mjs`)

const config = {
  rootDir: "..",
  files: "test/javascript/compiled/test.js",
  nodeResolve: true,
  browserStartTimeout: 180000,
  testsStartTimeout: 180000,
  testsFinishTimeout: 300000,
  testFramework: {
    path: require.resolve("web-test-runner-qunit"),
    config: {},
  },
}

if (process.env.CI) {
  const sauce = createSauceLabsLauncher(
    {
      user: process.env.SAUCE_USERNAME,
      key: process.env.SAUCE_ACCESS_KEY,
      region: "us",
    },
    {
      build: buildId(),
      name: "ActionCable JS Client",
    }
  )

  config.browsers = [
    sauce({
      browserName: "chrome",
      browserVersion: "98",
      platformName: "Windows 10",
      "wdio:enforceWebDriverClassic": true,
    }),
    sauce({
      browserName: "firefox",
      browserVersion: "94",
      platformName: "Windows 10",
      "wdio:enforceWebDriverClassic": true,
    }),
    sauce({
      browserName: "safari",
      browserVersion: "16",
      platformName: "macOS 13",
    }),
    sauce({
      browserName: "microsoftedge",
      browserVersion: "latest",
      platformName: "Windows 11",
    }),
  ]
}

function buildId() {
  const { BUILDKITE_JOB_ID } = process.env
  return BUILDKITE_JOB_ID ? `Buildkite ${BUILDKITE_JOB_ID}` : ""
}

export default config
