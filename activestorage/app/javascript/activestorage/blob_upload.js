export class BlobUpload {
  constructor(blob) {
    this.blob = blob
    this.file = blob.file

    const { url, headers } = blob.directUploadData

    this.xhr = new XMLHttpRequest
    this.xhr.open("PUT", url, true)
    this.xhr.responseType = "text"
    for (const key in headers) {
      this.xhr.setRequestHeader(key, headers[key])
    }
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
    this.callback(
      `Error storing "${this.file.name}". Status: ${this.xhr.status}`
    )
  }
}
