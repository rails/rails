# frozen_string_literal: true

require "cases/helper"

class PreloadHasOneLimitTest < ActiveRecord::TestCase
  def setup
    ActiveRecord::Schema.define do
      create_table :accounts, force: true do |t|
        t.string :name
      end

      create_table :payments, force: true do |t|
        t.integer :account_id
        t.datetime :created_on
      end
    end

    @acc1 = Account.create!(name: "A1")
    @acc2 = Account.create!(name: "A2")

    @p1_latest = Payment.create!(account: @acc1, created_on: 2.days.ago)
    Payment.create!(account: @acc1, created_on: 3.days.ago)

    Payment.create!(account: @acc2, created_on: 3.days.ago)
    @p2_latest = Payment.create!(account: @acc2, created_on: 1.day.ago)
  end

  def test_preload_scoped_has_one_with_limit_uses_eager_load
    accounts = Account.where(id: [@acc1.id, @acc2.id]).preload(:last_payment).to_a

    assert_equal @p1_latest.id, accounts[0].last_payment.id
    assert_equal @p2_latest.id, accounts[1].last_payment.id
  end
end

class Account < ActiveRecord::Base
  has_one :last_payment, -> { order(created_on: :desc).limit(1) }, class_name: "Payment"
end

class Payment < ActiveRecord::Base
  belongs_to :account
end
