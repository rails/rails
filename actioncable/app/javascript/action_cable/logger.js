import adapters from "./adapters"

export default {
  log(...messages) {
    if (this.enabled) {
      messages.push(Date.now())
      adapters.logger.log("[ActionCable]", ...messages)
    }
  },
}
