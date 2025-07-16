import { FileChecksum } from "./file_checksum"
import { BlobRecord } from "./blob_record"
import { BlobUpload } from "./blob_upload"

let id = 0

export class DirectUpload {
  constructor(file, url, delegate, customHeaders = {}, key = null) {
    this.id = ++id
    this.file = file
    this.url = url
    this.delegate = delegate
    this.customHeaders = customHeaders
    this.key = key
  }

  create(callback) {
    FileChecksum.create(this.file, (error, checksum) => {
      if (error) {
        callback(error)
        return
      }

      const blob = new BlobRecord(this.file, checksum, this.url, this.customHeaders, this.key)
      notify(this.delegate, "directUploadWillCreateBlobWithXHR", blob.xhr)

      blob.create(error => {
        if (error) {
          callback(error)
        } else {
          const upload = new BlobUpload(blob)
          notify(this.delegate, "directUploadWillStoreFileWithXHR", upload.xhr)
          upload.create(error => {
            if (error) {
              callback(error)
            } else {
              callback(null, blob.toJSON())
            }
          })
        }
      })
    })
  }
}

function notify(object, methodName, ...messages) {
  if (object && typeof object[methodName] == "function") {
    return object[methodName](...messages)
  }
}
