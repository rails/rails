import adapters from "./adapters"

let enabled

export function log(...messages) {
  if (enabled) {
    messages.push(Date.now())
    adapters.logger.log("[ActionCable]", ...messages)
  }
}

export function startDebugging() {
  enabled = true
}

export function stopDebugging() {
  enabled = false
}
