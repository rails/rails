import { start } from "./ujs"
import { DirectUpload } from "./direct_upload"
import { DirectUploadController } from "./direct_upload_controller"
import { DirectUploadsController } from "./direct_uploads_controller"
export { start, DirectUpload, DirectUploadController, DirectUploadsController }

function autostart() {
  if (window.ActiveStorage) {
    start()
  }
}

setTimeout(autostart, 1)
