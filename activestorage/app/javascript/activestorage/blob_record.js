import { getMetaValue } from "./helpers"

export class BlobRecord {
  constructor(file, checksum, url) {
    this.file = file

    this.attributes = {
      filename: file.name,
      content_type: file.type,
      byte_size: file.size,
      checksum: checksum
    }

    this.xhr = new XMLHttpRequest
    this.xhr.open("POST", url, true)
    this.xhr.responseType = "json"
    this.xhr.setRequestHeader("Content-Type", "application/json")
    this.xhr.setRequestHeader("Accept", "application/json")
    this.xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest")
    this.xhr.setRequestHeader("X-CSRF-Token", getMetaValue("csrf-token"))
    this.xhr.addEventListener("load", event => this.requestDidLoad(event))
    this.xhr.addEventListener("error", event => this.requestDidError(event))
  }

  create(callback) {
    this.callback = callback
    this.xhr.send(JSON.stringify({ blob: this.attributes }))
  }

  requestDidLoad(event) {
    const { status, response } = this.xhr
    if (status >= 200 && status < 300) {
      const { direct_upload } = response
      delete response.direct_upload
      this.attributes = response
      this.directUploadData = direct_upload
      this.callback(null, this.toJSON())
    } else {
      this.requestDidError(event)
    }
  }

  requestDidError(event) {
    this.callback(`Error creating Blob for "${this.file.name}". Status: ${this.xhr.status}`)
  }

  toJSON() {
    const result = {}
    for (const key in this.attributes) {
      result[key] = this.attributes[key]
    }
    return result
  }
}
