import { FileChecksum } from "./file_checksum"
import { BlobRecord } from "./blob_record"
import { BlobUpload } from "./blob_upload"

let id = 0

export class DirectUpload {
  constructor(file, options = {}) {
    this.id = id++
    this.file = file
    this.url = options.url
    this.delegate = options.delegate
  }

  create(callback) {
    const fileChecksum = new FileChecksum(this.file)
    fileChecksum.create((error, checksum) => {
      const blob = new BlobRecord(this.file, checksum, this.url)
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
