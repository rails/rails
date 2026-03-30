import { register, authenticate } from "../../../../lib/passkeys/app/javascript/action_pack/webauthn"
import { stubCredentialsCreate, stubCredentialsGet } from "../test_helpers/index"

const { module, test } = QUnit

module("WebAuthn", () => {
  module("#register", () => {
    test("returns client_data_json, attestation_object, and transports", async assert => {
      const restore = stubCredentialsCreate({ transports: ["internal"] })

      try {
        const result = await register({
          challenge: btoa("test-challenge"),
          rp: { id: "example.com", name: "Example App" },
          user: { id: btoa("user-1"), name: "jane@example.com", displayName: "Jane Doe" },
          pubKeyCredParams: [{ type: "public-key", alg: -7 }]
        })

        assert.ok(result.client_data_json, "has client_data_json")
        assert.ok(result.attestation_object, "has attestation_object")
        assert.deepEqual(result.transports, ["internal"], "has transports")
      } finally {
        restore()
      }
    })
  })

  module("#authenticate", () => {
    test("returns id, client_data_json, authenticator_data, and signature", async assert => {
      const restore = stubCredentialsGet({ id: "cred-123" })

      try {
        const result = await authenticate({
          challenge: btoa("test-challenge"),
          rpId: "example.com",
          allowCredentials: []
        })

        assert.equal(result.id, "cred-123", "has credential id")
        assert.ok(result.client_data_json, "has client_data_json")
        assert.ok(result.authenticator_data, "has authenticator_data")
        assert.ok(result.signature, "has signature")
      } finally {
        restore()
      }
    })
  })
})
