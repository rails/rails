import { sha256 } from "js-sha256"

function hexToBase64(hexString) {
  const bytes = []
  for (let i = 0; i < hexString.length; i += 2) {
    bytes.push(parseInt(hexString.substring(i, i + 2), 16))
  }

  let binary = ""
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i])
  }

  return btoa(binary)
}

export const sha256Algorithm = {
  createBuffer: () => sha256.create(),
  append: (buffer, data) => buffer.update(data),
  getChecksum: (buffer) => {
    const hexDigest = buffer.hex()
    return `sha256:${hexToBase64(hexDigest)}`
  }
}
