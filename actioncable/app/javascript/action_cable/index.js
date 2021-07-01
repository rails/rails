import Connection from "./connection"
import ConnectionMonitor from "./connection_monitor"
import Consumer, { createWebSocketURL } from "./consumer"
import INTERNAL from "./internal"
import Subscription from "./subscription"
import Subscriptions from "./subscriptions"
import SubscriptionGuarantor from "./subscription_guarantor"
import adapters from "./adapters"
import logger from "./logger"

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
