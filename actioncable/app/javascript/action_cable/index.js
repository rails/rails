import adapters from "./adapters"
import Connection from "./connection"
import ConnectionMonitor from "./connection_monitor"
import Consumer, { createWebSocketURL } from "./consumer"
import INTERNAL from "./internal"
import logger from "./logger"
import Subscription from "./subscription"
import SubscriptionGuarantor from "./subscription_guarantor"
import Subscriptions from "./subscriptions"

export {
  Connection,
  ConnectionMonitor,
  Consumer,
  INTERNAL,
  Subscription,
  Subscriptions,
  SubscriptionGuarantor,
  adapters,
  createWebSocketURL,
  logger,
}

export function createConsumer(url = getConfig("url") || INTERNAL.default_mount_path) {
  return new Consumer(url)
}

export function getConfig(name) {
  const element = document.head.querySelector(`meta[name='action-cable-${name}']`)
  if (element) {
    return element.getAttribute("content")
  }
}
