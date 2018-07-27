import SparkMD5 from "spark-md5"

const fileSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice

export class FileChecksum {
  static create(file, callback) {
    const instance = new FileChecksum(file)
    instance.create(callback)
  }

  constructor(file) {
    this.file = file
    this.chunkSize = 2097152 // 2MB
    this.chunkCount = Math.ceil(this.file.size / this.chunkSize)
    this.chunkIndex = 0
  }

  create(callback) {
    this.callback = callback
    this.md5Buffer = new SparkMD5.ArrayBuffer
    this.fileReader = new FileReader
    this.fileReader.addEventListener("load", event => this.fileReaderDidLoad(event))
    this.fileReader.addEventListener("error", event => this.fileReaderDidError(event))
    this.readNextChunk()
  }

  fileReaderDidLoad(event) {
    this.md5Buffer.append(event.target.result)

    if (!this.readNextChunk()) {
      const binaryDigest = this.md5Buffer.end(true)
      const base64digest = btoa(binaryDigest)
      this.callback(null, base64digest)
    }
  }

  fileReaderDidError(event) {
    this.callback(`Error reading ${this.file.name}`)
  }

  readNextChunk() {
    if (this.chunkIndex < this.chunkCount || this.chunkIndex == 0 && this.chunkCount == 0) {
      const start = this.chunkIndex * this.chunkSize
      const end = Math.min(start + this.chunkSize, this.file.size)
      const bytes = fileSlice.call(this.file, start, end)
      this.fileReader.readAsArrayBuffer(bytes)
      this.chunkIndex++
      return true
    } else {
      return false
    }
  }
}
