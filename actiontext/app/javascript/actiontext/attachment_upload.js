import { DirectUpload, dispatchEvent } from "@rails/activestorage"

export class AttachmentUpload {
  constructor(attachment, element) {
    this.attachment = attachment
    this.element = element
    this.directUpload = new DirectUpload(attachment.file, this.directUploadUrl, this)
  }

  start() {
    this.directUpload.create(this.directUploadDidComplete.bind(this))
    this.dispatch("start")
  }

  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", event => {
      // Scale upload progress to 0-90% range
      const progress = (event.loaded / event.total) * 90
      this.attachment.setUploadProgress(progress)
      if (progress) {
        this.dispatch("progress", { progress: progress })
      }
    })

    // Start simulating progress after upload completes
    xhr.upload.addEventListener("loadend", () => {
      this.simulateResponseProgress(xhr)
    })
  }

  simulateResponseProgress(xhr) {
    let progress = 90
    const startTime = Date.now()

    const updateProgress = () => {
      // Simulate progress from 90% to 99% over estimated time
      const elapsed = Date.now() - startTime
      const estimatedResponseTime = this.estimateResponseTime()
      const responseProgress = Math.min(elapsed / estimatedResponseTime, 1)
      progress = 90 + (responseProgress * 9) // 90% to 99%

      this.attachment.setUploadProgress(progress)
      this.dispatch("progress", { progress })

      // Continue until response arrives or we hit 99%
      if (xhr.readyState !== XMLHttpRequest.DONE && progress < 99) {
        requestAnimationFrame(updateProgress)
      }
    }

    // Stop simulation when response arrives
    xhr.addEventListener("loadend", () => {
      this.attachment.setUploadProgress(100)
      this.dispatch("progress", { progress: 100 })
    })

    requestAnimationFrame(updateProgress)
  }

  estimateResponseTime() {
    // Base estimate: 1 second for small files, scaling up for larger files
    const fileSize = this.attachment.file.size
    const MB = 1024 * 1024

    if (fileSize < MB) {
      return 1000 // 1 second for files under 1MB
    } else if (fileSize < 10 * MB) {
      return 2000 // 2 seconds for files 1-10MB
    } else {
      return 3000 + (fileSize / MB * 50) // 3+ seconds for larger files
    }
  }

  directUploadDidComplete(error, attributes) {
    if (error) {
      this.dispatchError(error)
    } else {
      this.attachment.setAttributes({
        sgid: attributes.attachable_sgid,
        url: this.createBlobUrl(attributes.signed_id, attributes.filename)
      })
      this.dispatch("end")
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
      alert(error);
    }
  }

  get directUploadUrl() {
    return this.element.dataset.directUploadUrl
  }

  get blobUrlTemplate() {
    return this.element.dataset.blobUrlTemplate
  }
}
