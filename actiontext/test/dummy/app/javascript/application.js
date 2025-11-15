import "trix"
import "@rails/actiontext"

addEventListener("click", ({ target }) => {
  if (target.matches(`[data-trix-action~="x-attach"]`)) {
    const toolbar = target.closest("trix-toolbar")
    const template = target.querySelector("template")
    const actionTextAttachment = {
      ...JSON.parse(template.getAttribute("data-action-text-attachment")),
      content: template.innerHTML
    }

    for (const editorElement of document.querySelectorAll(`trix-editor[toolbar="${toolbar.id}"]`)) {
      editorElement.editor.insertAttachment(new Trix.Attachment(actionTextAttachment))
    }
  }
})
