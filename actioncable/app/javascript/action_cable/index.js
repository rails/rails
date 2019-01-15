import Connection from "./connection"
import ConnectionMonitor from "./connection_monitor"
import Consumer from "./consumer"
import INTERNAL from "./internal"
import Subscription from "./subscription"
import Subscriptions from "./subscriptions"
import adapters from "./adapters"
import logger from "./logger"

export {
  Connection,
  ConnectionMonitor,
  Consumer,
  INTERNAL,
  Subscription,
  Subscriptions,
  adapters,
  logger,
}

export function createConsumer(url = getConfig("url") || INTERNAL.default_mount_path) {
  return new Consumer(createWebSocketURL(url))
}

export function getConfig(name) {
  const element = document.head.querySelector(`meta[name='action-cable-${name}']`)
  if (element) {
    return element.getAttribute("content")
  }
}

export function createWebSocketURL(url) {
  if (url && !/^wss?:/i.test(url)) {
    const a = document.createElement("a")
    a.href = url
    // Fix populating Location properties in IE. Otherwise, protocol will be blank.
    a.href = a.href
    a.protocol = a.protocol.replace("http", "ws")
    return a.href
  } else {
    return url
  }
}
