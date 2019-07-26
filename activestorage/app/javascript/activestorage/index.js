import { start } from "./ujs"
import { DirectUpload } from "./direct_upload"
export { start, DirectUpload }

function autostart() {
  if (window.ActiveStorage) {
    start()
  }
}

setTimeout(autostart, 1)
