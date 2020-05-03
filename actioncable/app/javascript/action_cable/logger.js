import adapters from "./adapters"

// The logger can be enabled with:
//
//   ActionCable.logger.enabled = true
//

export default {
  log(...messages) {
    if (this.enabled) {
      messages.push(Date.now())
      adapters.logger.log("[ActionCable]", ...messages)
    }
  },
}
