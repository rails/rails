import { FileChecksum } from "./file_checksum"
import { BlobRecord } from "./blob_record"
import { BlobUpload } from "./blob_upload"
import {
  isFunc,
} from "../../javascript/activestorage/helpers"

let id = 0

export class DirectUpload {
  constructor(file, url, delegate) {
    this.id = ++id
    this.file = file
    this.url = url
    this.delegate = delegate
  }

  create(callback) {
    FileChecksum.create(this.file, (error, checksum) => {
      if (error) {
        callback(error)
        return
      }

      const blob = new BlobRecord(this.file, checksum, this.url)
      notify(this.delegate, "directUploadWillStoreFileWithXHR", blob.xhr)

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

const notifyError = () => {
  throw new Error(
    "Delgate must either be a callback or a class or object that implements directUploadWillStoreFileWithXHR."
  )
}

function notify(obj, methodName, ...messages) {
  if (
    obj === undefined ||
    typeof obj === "string" ||
    Array.isArray(obj) ||
    typeof obj === "boolean" || obj === null

  ) {
    notifyError()
  }
  if (typeof obj[methodName] === "function") {
    return obj[methodName](...messages)
  }
  if (isFunc(obj)) {
    return obj(...messages)
  }
}
