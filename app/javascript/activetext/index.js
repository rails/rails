import * as Trix from "trix"
import { DirectUpload } from "activestorage"

addEventListener("trix-attachment-add", event => {
  const { attachment } = event
  if (!attachment.file) return

  const { directUploadUrl, blobUrlTemplate } = event.target.dataset

  const delegate = {
    directUploadWillStoreFileWithXHR: (xhr) => {
      xhr.upload.addEventListener("progress", event => {
        const progress = event.loaded / event.total * 100
        attachment.setUploadProgress(progress)
      })
    }
  }

  const directUpload = new DirectUpload(attachment.file, directUploadUrl, delegate)

  directUpload.create((error, attributes) => {
    if (error) {
      console.warn("Failed to store file for attachment", attachment, error)
    } else {
      const sgid = attributes.attachable_sgid

      const url = blobUrlTemplate
        .replace(":signed_id", attributes.signed_id)
        .replace(":filename", encodeURIComponent(attributes.filename))

      attachment.setAttributes({ sgid, url })
    }
  })
})
