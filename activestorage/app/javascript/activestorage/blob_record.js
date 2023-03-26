import { getMetaValue } from "./helpers"

export class BlobRecord {
  constructor(file, checksum, url, customHeaders = {}) {
    this.file = file

    this.attributes = {
      filename: file.name,
      content_type: file.type || "application/octet-stream",
      byte_size: file.size,
      checksum: checksum
    }

    this.xhr = new XMLHttpRequest
    this.xhr.open("POST", url, true)
    this.xhr.responseType = "json"
    this.xhr.setRequestHeader("Content-Type", "application/json")
    this.xhr.setRequestHeader("Accept", "application/json")
    this.xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest")
    Object.keys(customHeaders).forEach((headerKey) => {
      this.xhr.setRequestHeader(headerKey, customHeaders[headerKey])
    })

    const csrfToken = getMetaValue("csrf-token")
    if (csrfToken != undefined) {
      this.xhr.setRequestHeader("X-CSRF-Token", csrfToken)
    }

    this.xhr.addEventListener("load", event => this.requestDidLoad(event))
    this.xhr.addEventListener("error", event => this.requestDidError(event))
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
