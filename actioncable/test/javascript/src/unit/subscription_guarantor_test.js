import * as ActionCable from "../../../../app/javascript/action_cable/index"

const {module, test} = QUnit

module("ActionCable.SubscriptionGuarantor", hooks => {
  let guarantor
  hooks.beforeEach(() => guarantor = new ActionCable.SubscriptionGuarantor({}))

  module("#guarantee", () => {
    test("guarantees subscription only once", assert => {
      const sub = {}

      assert.equal(guarantor.pendingSubscriptions.length, 0)
      guarantor.guarantee(sub)
      assert.equal(guarantor.pendingSubscriptions.length, 1)
      guarantor.guarantee(sub)
      assert.equal(guarantor.pendingSubscriptions.length, 1)
    })
  }),

  module("#forget", () => {
    test("removes subscription", assert => {
      const sub = {}

      assert.equal(guarantor.pendingSubscriptions.length, 0)
      guarantor.guarantee(sub)
      assert.equal(guarantor.pendingSubscriptions.length, 1)
      guarantor.forget(sub)
      assert.equal(guarantor.pendingSubscriptions.length, 0)
    })
  })
})
