export class BlobUpload {
  constructor(blob) {
    this.blob = blob
    this.file = blob.file

    this.xhr = new XMLHttpRequest
    this.xhr.open("PUT", blob.uploadURL, true)
    this.xhr.setRequestHeader("Content-Type", blob.attributes.content_type)
    this.xhr.setRequestHeader("Content-MD5", blob.attributes.checksum)
    this.xhr.addEventListener("load", event => this.requestDidLoad(event))
    this.xhr.addEventListener("error", event => this.requestDidError(event))
  }

  create(callback) {
    this.callback = callback
    this.xhr.send(this.file)
  }

  requestDidLoad(event) {
    const { status, response } = this.xhr
    if (status >= 200 && status < 300) {
      this.callback(null, response)
    } else {
      this.requestDidError(event)
    }
  }

  requestDidError(event) {
    this.callback(`Error storing "${this.file.name}". Status: ${this.xhr.status}`)
  }
}
