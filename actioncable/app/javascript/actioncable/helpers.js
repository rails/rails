
export function startDebugging() {
  return this.debugging = true
}

export function stopDebugging() {
  return this.debugging = null
}

export function log(...messages) {
  if (this.debugging) {
    messages.push(Date.now())
    this.logger = window.console
    return this.logger.log("[ActionCable]", ...messages)
  }
}
