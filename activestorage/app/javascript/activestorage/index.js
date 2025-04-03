import { start } from "./ujs"
import { DirectUpload } from "./direct_upload"
import { DirectUploadController } from "./direct_upload_controller"
import { DirectUploadsController } from "./direct_uploads_controller"
import { dispatchEvent } from "./helpers"
export { start, DirectUpload, DirectUploadController, DirectUploadsController, dispatchEvent }

function autostart() {
  if (window.ActiveStorage) {
    start()
  }
}

setTimeout(autostart, 1)
