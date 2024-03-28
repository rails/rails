import { DirectUpload } from "@rails/activestorage"

export class AttachmentUpload {
  constructor(delegate, file) {
    this.delegate = delegate
    this.file = file
    this.directUpload = new DirectUpload(file, this.directUploadUrl, this)
  }

  start() {
    return new Promise(resolve => {
      this.directUpload.create((error, attributes) => resolve(this.directUploadDidComplete(error, attributes)))
    })
  }

  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", event => {
      const progress = event.loaded / event.total * 100
      notify(this.delegate, "setUploadProgress", progress)
    })
  }

  directUploadDidComplete(error, attributes) {
    if (error) {
      throw new Error(`Direct upload failed: ${error}`)
    }

    return notify(this.delegate, "uploadDidComplete", {
      sgid: attributes.attachable_sgid,
      url: this.createBlobUrl(attributes.signed_id, attributes.filename)
    })
  }

  createBlobUrl(signedId, filename) {
    return this.blobUrlTemplate
      .replace(":signed_id", signedId)
      .replace(":filename", encodeURIComponent(filename))
  }

  get directUploadUrl() {
    return this.delegate.directUploadUrl
  }

  get blobUrlTemplate() {
    return this.delegate.blobUrlTemplate
  }
}

function notify(object, methodName, ...messages) {
  if (object && typeof object[methodName] == "function") {
    return object[methodName](...messages)
  }
}
