import { AttachmentUpload } from "./attachment_upload"

addEventListener("trix-attachment-add", event => {
  const { attachment, target } = event

  if (attachment.file) {
    const delegate = {
      directUploadUrl: target.dataset.directUploadUrl,
      blobUrlTemplate: target.dataset.blobUrlTemplate,
      setUploadProgress: progress => attachment.setUploadProgress(progress),
      uploadDidComplete: attributes => attachment.setAttributes(attributes),
    }

    const upload = new AttachmentUpload(delegate, attachment.file)
    upload.start()
  }
})

export { AttachmentUpload }
