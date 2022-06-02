import adapters from "./adapters"

// The logger is disabled by default. You can enable it with:
//
//   ActionCable.logger.enabled = true
//
//   Example:
//
//   import * as ActionCable from '@rails/actioncable'
//
//   ActionCable.logger.enabled = true
//   ActionCable.logger.log('Connection Established.')
//

export default {
  log(...messages) {
    if (this.enabled) {
      messages.push(Date.now())
      adapters.logger.log("[ActionCable]", ...messages)
    }
  },
}
