/* global process */

import { startTestRunner } from "@web/test-runner"
import { classifyRun } from "./sauce_labs.mjs"

const argv = ["--config", "web-test-runner.config.mjs", ...process.argv.slice(2)]

startTestRunner({ autoExitProcess: false, argv }).then((runner) => {
  if (!runner) {
    return
  }

  process.on("SIGINT", () => runner.stop())
  process.on("SIGTERM", () => runner.stop())

  runner.on("stopped", (passed) => {
    const sessions = Array.from(runner.sessions.all())
    const { exitStatus, reason } = classifyRun(passed, sessions)

    if (exitStatus !== 0) {
      console.error(`Action Cable JavaScript tests failed: ${reason}`)
    }

    process.exit(exitStatus)
  })
})
