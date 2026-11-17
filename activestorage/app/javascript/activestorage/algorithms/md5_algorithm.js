import SparkMD5 from "spark-md5"

export const md5Algorithm = {
  createBuffer: () => new SparkMD5.ArrayBuffer(),
  append: (buffer, data) => buffer.append(data),
  getChecksum: (buffer) => btoa(buffer.end(true))
}
