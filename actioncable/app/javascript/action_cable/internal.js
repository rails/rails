export default {
  "message_types": {
    "welcome": "welcome",
    "disconnect": "disconnect",
    "ping": "ping",
    "pong": "pong",
    "confirmation": "confirm_subscription",
    "rejection": "reject_subscription"
  },
  "disconnect_reasons": {
    "unauthorized": "unauthorized",
    "invalid_request": "invalid_request",
    "server_restart": "server_restart",
    "remote": "remote",
    "heartbeat_timeout": "heartbeat_timeout"
  },
  "default_mount_path": "/cable",
  "protocols": [
    "actioncable-v1.1-json",
    "actioncable-v1-json",
    "actioncable-unsupported"
  ]
}
