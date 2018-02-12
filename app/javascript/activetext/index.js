import * as Trix from "trix"
import { DirectUpload } from "activestorage"

// FIXME: Hard coded routes
const directUploadsURL = "/rails/active_storage/direct_uploads"
const blobsURL = "/rails/active_storage/blobs"

addEventListener("trix-attachment-add", event => {
  const { attachment } = event
  if (!attachment.file) return

  const delegate = {
    directUploadWillStoreFileWithXHR: (xhr) => {
      xhr.upload.addEventListener("progress", event => {
        const progress = event.loaded / event.total * 100
        attachment.setUploadProgress(progress)
      })
    }
  }

  const directUpload = new DirectUpload(attachment.file, directUploadsURL, delegate)

  directUpload.create((error, attributes) => {
    if (error) {
      console.warn("Failed to store file for attachment", attachment, error)
    } else {
      console.log("Created blob for attachment", attributes, attachment)
      attachment.setAttributes({
        url: `${blobsURL}/${attributes.signed_id}/${encodeURIComponent(attachment.file.name)}`,
        sgid: attributes.attachable_sgid
      })
    }
  })
})
