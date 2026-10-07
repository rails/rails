import { AttachmentUpload } from "./attachment_upload"

addEventListener("trix-initialize", event => {
  if (!event.target.dataset.directUploadUrl) {
    event.target.toolbarElement.querySelectorAll("[data-trix-action=attachFiles]").forEach(button => {
      const group = button.closest("[data-trix-button-group]")

      button.remove()

      if (group && group.childElementCount === 0) group.remove()
    })
  }
})

addEventListener("trix-file-accept", event => {
  if (!event.target.dataset.directUploadUrl) {
    event.preventDefault()
  }
})

addEventListener("trix-attachment-add", event => {
  const { attachment, target } = event

  if (attachment.file) {
    const upload = new AttachmentUpload(attachment, target, attachment.file)
    const onProgress = event => attachment.setUploadProgress(event.detail.progress)

    target.addEventListener("direct-upload:progress", onProgress)

    upload.start()
      .then(attributes => attachment.setAttributes(attributes))
      .catch(error => alert(error))
      .finally(() => target.removeEventListener("direct-upload:progress", onProgress))
  }
})

export { AttachmentUpload }
