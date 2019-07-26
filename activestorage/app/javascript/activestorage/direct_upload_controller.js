import { DirectUpload } from "./direct_upload"
import { dispatchEvent } from "./helpers"

export class DirectUploadController {
  constructor(input, file) {
    this.input = input
    this.file = file
    this.directUpload = new DirectUpload(this.file, this.url, this)
    this.dispatch("initialize")
  }

  start(callback) {
    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = this.input.name
    this.input.insertAdjacentElement("beforebegin", hiddenInput)

    this.dispatch("start")

    this.directUpload.create((error, attributes) => {
      if (error) {
        hiddenInput.parentNode.removeChild(hiddenInput)
        this.dispatchError(error)
      } else {
        hiddenInput.value = attributes.signed_id
      }

      this.dispatch("end")
      callback(error)
    })
  }

  uploadRequestDidProgress(event) {
    const progress = event.loaded / event.total * 100
    if (progress) {
      this.dispatch("progress", { progress })
    }
  }

  get url() {
    return this.input.getAttribute("data-direct-upload-url")
  }

  dispatch(name, detail = {}) {
    detail.file = this.file
    detail.id = this.directUpload.id
    return dispatchEvent(this.input, `direct-upload:${name}`, { detail })
  }

  dispatchError(error) {
    const event = this.dispatch("error", { error })
    if (!event.defaultPrevented) {
      alert(error)
    }
  }

  // DirectUpload delegate

  directUploadWillCreateBlobWithXHR(xhr) {
    this.dispatch("before-blob-request", { xhr })
  }

  directUploadWillStoreFileWithXHR(xhr) {
    this.dispatch("before-storage-request", { xhr })
    xhr.upload.addEventListener("progress", event => this.uploadRequestDidProgress(event))
  }
}
