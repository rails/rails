import { createSauceLabsLauncher as createBaseSauceLabsLauncher } from "@web/test-runner-saucelabs"

export const SAUCE_INFRASTRUCTURE_EXIT_STATUS = 3

const SAUCE_CONNECT_RETRY_LIMIT = 1
const SAUCE_CONNECT_RETRY_DELAY = 5000
const CLIENT_WEBDRIVER_ERRORS = new Set([
  "invalid argument",
])

const sessionState = new Map()
const sauceConnectFailures = []

export function createSauceLabsLauncher(saucelabsOptions, saucelabsCapabilities, sauceConnectOptions) {
  const sauce = createBaseSauceLabsLauncher(saucelabsOptions, saucelabsCapabilities, sauceConnectOptions)

  return function sauceLabsLauncher(capabilities) {
    return instrumentLauncher(sauce(capabilities), capabilities)
  }
}

export function classifyRun(passed, sessions) {
  if (passed) {
    return { exitStatus: 0, reason: "passed" }
  }

  const failedSessions = sessions.filter((session) => !session.passed)

  if (failedSessions.some(hasTestFailure)) {
    return { exitStatus: 1, reason: "test failure" }
  }

  if (failedSessions.some(hasMissingAssets)) {
    return { exitStatus: 1, reason: "missing browser assets" }
  }

  if (sauceConnectFailures.length > 0) {
    return { exitStatus: SAUCE_INFRASTRUCTURE_EXIT_STATUS, reason: "sauce connect setup failure" }
  }

  if (failedSessions.some(hasClientSessionFailure)) {
    return { exitStatus: 1, reason: "webdriver session request failure" }
  }

  if (failedSessions.some(hasInfrastructureSessionFailure)) {
    return { exitStatus: SAUCE_INFRASTRUCTURE_EXIT_STATUS, reason: "sauce session setup failure" }
  }

  if (failedSessions.length > 0 && failedSessions.every(noBrowserTestResults)) {
    return { exitStatus: SAUCE_INFRASTRUCTURE_EXIT_STATUS, reason: "sauce browser did not produce test results" }
  }

  return { exitStatus: 1, reason: "non-infrastructure failure" }
}

function instrumentLauncher(launcher, capabilities) {
  addTransformResponse(launcher, capabilities)
  wrapInitialize(launcher, capabilities)
  wrapStartSession(launcher, capabilities)

  return launcher
}

function addTransformResponse(launcher, capabilities) {
  const previousTransformResponse = launcher.options.transformResponse

  launcher.options.transformResponse = function(response, requestOptions) {
    const transformed = previousTransformResponse ? previousTransformResponse(response, requestOptions) : response
    const requestBody = parseJson(requestOptions.body)

    if (requestBody && requestBody.capabilities) {
      recordSessionCreationResponse(launcher, capabilities, transformed)
    }

    return transformed
  }
}

function wrapInitialize(launcher, capabilities) {
  const original = launcher.initialize.bind(launcher)

  launcher.initialize = function(...args) {
    return retrySauceConnect(function() {
      return original(...args)
    }, launcher, capabilities, 0)
  }
}

function retrySauceConnect(callback, launcher, capabilities, retry) {
  return callback().catch((error) => {
    resetSauceConnect(launcher)

    if (retry >= SAUCE_CONNECT_RETRY_LIMIT) {
      recordSauceConnectFailure(launcher, capabilities, error)
      throw error
    }

    console.warn(
      "[Saucelabs] Retrying Sauce Connect setup after startup failure " +
        `(${retry + 1}/${SAUCE_CONNECT_RETRY_LIMIT})`
    )

    return delay(SAUCE_CONNECT_RETRY_DELAY).then(() => {
      return retrySauceConnect(callback, launcher, capabilities, retry + 1)
    })
  })
}

function resetSauceConnect(launcher) {
  if (!launcher.manager) {
    return
  }

  launcher.manager.connection = undefined
  launcher.manager.connectionPromise = undefined
}

function wrapStartSession(launcher, capabilities) {
  const original = launcher.startSession.bind(launcher)

  launcher.startSession = function(sessionId, url) {
    const state = stateFor(sessionId)
    state.capabilities = capabilities
    state.launcher = launcher

    return original(sessionId, url).then((result) => {
      state.webdriverSessionStarted = true
      state.sauceSessionId = launcher.driver && launcher.driver.sessionId
      return result
    }).catch((error) => {
      state.startSessionError = structuredError(error)

      if (!state.sessionCreationResponse) {
        state.infrastructureFailure = {
          type: "webdriver-session-transport",
          error: structuredError(error),
        }
      }

      throw error
    })
  }
}

function recordSauceConnectFailure(launcher, capabilities, error) {
  sauceConnectFailures.push({
    type: "sauce-connect-setup",
    browserName: launcher.name,
    capabilities,
    error: structuredError(error),
  })
}

function recordSessionCreationResponse(launcher, capabilities, response) {
  const state = stateForCurrentLauncher(launcher)
  const responseData = structuredResponse(response)

  state.capabilities = capabilities
  state.sessionCreationResponse = responseData

  if (responseData.webdriverError) {
    if (CLIENT_WEBDRIVER_ERRORS.has(responseData.webdriverError)) {
      state.clientFailure = {
        type: "webdriver-session-response",
        response: responseData,
      }
    } else {
      state.infrastructureFailure = {
        type: "webdriver-session-response",
        response: responseData,
      }
    }
  }
}

function stateForCurrentLauncher(launcher) {
  const session = Array.from(sessionState.values()).find((candidate) => {
    return candidate.launcher === launcher && !candidate.webdriverSessionStarted
  })

  return session || stateFor(`launcher:${launcher.name}`)
}

function stateFor(sessionId) {
  if (!sessionState.has(sessionId)) {
    sessionState.set(sessionId, {})
  }

  return sessionState.get(sessionId)
}

function hasTestFailure(session) {
  return suiteHasFailure(session.testResults)
}

function suiteHasFailure(suite) {
  return Boolean(
    suite && (
      suite.tests.some((test) => !test.passed && !test.skipped) ||
      suite.suites.some((child) => suiteHasFailure(child))
    )
  )
}

function hasMissingAssets(session) {
  return session.request404s && session.request404s.length > 0
}

function hasClientSessionFailure(session) {
  const state = sessionState.get(session.id)
  return Boolean(state && state.clientFailure)
}

function hasInfrastructureSessionFailure(session) {
  const state = sessionState.get(session.id)
  return Boolean(state && state.infrastructureFailure)
}

function noBrowserTestResults(session) {
  return !hasTestResults(session) && !hasMissingAssets(session)
}

function hasTestResults(session) {
  return countTests(session.testResults) > 0
}

function countTests(suite) {
  if (!suite) {
    return 0
  }

  return suite.tests.length + suite.suites.reduce((count, child) => count + countTests(child), 0)
}

function structuredResponse(response) {
  const body = response && response.body
  const value = body && body.value

  return {
    statusCode: response && response.statusCode,
    webdriverError: value && value.error || body && body.error,
    webdriverStatus: body && body.status,
    hasValue: Boolean(value),
  }
}

function structuredError(error) {
  if (!error) {
    return {}
  }

  return {
    name: error.name,
    code: error.code,
    statusCode: error.statusCode,
    bodyPresent: Boolean(error.body),
    causeName: error.cause && error.cause.name,
    causeCode: error.cause && error.cause.code,
    causeStatusCode: error.cause && error.cause.statusCode,
  }
}

function parseJson(value) {
  if (typeof value !== "string") {
    return undefined
  }

  try {
    return JSON.parse(value)
  } catch (error) {
    Boolean(error)
    return undefined
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
