# frozen_string_literal: true

require "cases/helper"
require "models/subscriber"

# create_or_find_by retries with find_by! only when there is no surrounding
# transaction. The rest of the suite runs inside a transaction (transactional
# fixtures), so that branch is never exercised there — these tests run without
# one to cover the real top-level production path.
class CreateOrFindByOutsideTransactionTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    Subscriber.create!(nick: "cofb_bob", name: "Bob")
  end

  def teardown
    Subscriber.where(nick: "cofb_bob").delete_all
  end

  def test_create_or_find_by_with_polluted_scope_outside_a_transaction
    existing = Subscriber.find_by!(nick: "cofb_bob")

    found = Subscriber.where(nick: "cofb_alice").create_or_find_by(nick: "cofb_bob")

    assert_equal existing, found
  end

  def test_create_or_find_by_bang_with_polluted_scope_outside_a_transaction
    existing = Subscriber.find_by!(nick: "cofb_bob")

    found = Subscriber.where(nick: "cofb_alice").create_or_find_by!(nick: "cofb_bob")

    assert_equal existing, found
  end
end
