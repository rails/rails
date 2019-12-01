import { start } from "./ujs"
import { DirectUpload } from "./direct_upload"
import { dispatchEvent } from "./helpers"
export { start, DirectUpload, dispatchEvent }

function autostart() {
  if (window.ActiveStorage) {
    start()
  }
}

setTimeout(autostart, 1)
