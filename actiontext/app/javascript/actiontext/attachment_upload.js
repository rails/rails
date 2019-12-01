import { DirectUpload, dispatchEvent } from "@rails/activestorage"

export class AttachmentUpload {
  constructor(attachment, element) {
    this.attachment = attachment
    this.element = element
    this.directUpload = new DirectUpload(attachment.file, this.directUploadUrl, this)
  }

  start() {
    this.directUpload.create(this.directUploadDidComplete.bind(this))
  }

  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", event => {
      const progress = event.loaded / event.total * 100
      this.attachment.setUploadProgress(progress)
    })
  }

  directUploadDidComplete(error, attributes) {
    if (error) {
      this.dispatchError(error)
    } else {
      this.attachment.setAttributes({
        sgid: attributes.attachable_sgid,
        url: this.createBlobUrl(attributes.signed_id, attributes.filename)
      })
    }
  }

  createBlobUrl(signedId, filename) {
    return this.blobUrlTemplate
      .replace(":signed_id", signedId)
      .replace(":filename", encodeURIComponent(filename))
  }

  dispatch(name, detail = {}) {
    detail.attachment = this.attachment
    return dispatchEvent(this.element, `direct-upload:${name}`, { detail })
  }

  dispatchError(error) {
    const event = this.dispatch("error", { error })
    if (!event.defaultPrevented) {
      throw new Error(`Direct upload failed: ${error}`)
    }
  }

  get directUploadUrl() {
    return this.element.dataset.directUploadUrl
  }

  get blobUrlTemplate() {
    return this.element.dataset.blobUrlTemplate
  }
}
