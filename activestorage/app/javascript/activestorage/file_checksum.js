import { md5Algorithm } from "./algorithms/md5_algorithm"
import { sha256Algorithm } from "./algorithms/sha256_algorithm"

const fileSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice

const CHECKSUM_ALGORITHMS = {
  md5: md5Algorithm,
  sha256: sha256Algorithm,
}

export class FileChecksum {
  static create(file, callback, options = {}) {
    const instance = new FileChecksum(file, options)
    instance.create(callback)
  }

  constructor(file, options = {}) {
    this.file = file
    this.chunkSize = options.chunkSize || 2097152 // 2MB
    this.chunkCount = Math.ceil(this.file.size / this.chunkSize)
    this.chunkIndex = 0
    this.checksum_algorithm = (options.algorithm || "md5").toLowerCase()
  }

  create(callback) {
    this.callback = callback

    const algorithmConfig = CHECKSUM_ALGORITHMS[this.checksum_algorithm]
    if (algorithmConfig) {
      this.checksumBuffer = algorithmConfig.createBuffer()
      this.algorithmConfig = algorithmConfig

      this.fileReader = new FileReader
      this.fileReader.addEventListener("load", event => this._fileReaderDidLoad(event))
      this.fileReader.addEventListener("error", event => this.fileReaderDidError(event))
      this.readNextChunk()
    } else {
      this.callback(`Unsupported algorithm: ${this.checksum_algorithm}`)
    }
  }

  _fileReaderDidLoad(event) {
    this.algorithmConfig.append(this.checksumBuffer, event.target.result)

    if (!this.readNextChunk()) {
      const checksum = this.algorithmConfig.getChecksum(this.checksumBuffer)
      this.callback(null, checksum)
    }
  }

  fileReaderDidLoad(event) {
    this._fileReaderDidLoad(event)
  }

  fileReaderDidError(event) {
    this.callback(`Error reading ${this.file.name}`)
  }

  readNextChunk() {
    if (this.chunkIndex < this.chunkCount || (this.chunkIndex === 0 && this.chunkCount === 0)) {
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
