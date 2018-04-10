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
    this.xhr.addEventListener("load", this.requestDidLoad)
    this.xhr.addEventListener("error", this.requestDidError)
  }

  get status() {
    return this.xhr.status
  }

  get response() {
    const { responseType, response } = this.xhr
    if (responseType == "json") {
      return response
    } else {
      // Shim for IE 11: https://connect.microsoft.com/IE/feedback/details/794808
      return JSON.parse(response)
    }
  }

  create(callback) {
    this.callback = callback
    this.xhr.send(JSON.stringify({ blob: this.attributes }))
  }

  requestDidLoad(event) {
    if (this.status >= 200 && this.status < 300) {
      const { response } = this
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
    this.callback(`Error creating Blob for "${this.file.name}". Status: ${this.status}`)
  }

  toJSON() {
    const result = {}
    for (const key in this.attributes) {
      result[key] = this.attributes[key]
    }
    return result
  }
}
