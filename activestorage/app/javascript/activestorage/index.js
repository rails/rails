import { start } from "./ujs"
import { DirectUpload } from "./direct_upload"
import { DirectUploadController } from "./direct_upload_controller"
import { DirectUploadsController } from "./direct_uploads_controller"
import { dispatchEvent } from "./helpers"
import adapters from "./adapters"


export {
  start,
  DirectUpload,
  DirectUploadController,
  DirectUploadsController,
  dispatchEvent,
  adapters
}

function autostart() {
  if (window.ActiveStorage) {
    start()
  }
}

setTimeout(autostart, 1)
