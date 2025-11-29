# frozen_string_literal: true

require "cases/helper"

class Account
  extend ActiveModel::Callbacks
  include ActiveModel::Attributes
  include ActiveModel::SchematizedJson

  define_model_callbacks :save

  attribute :settings
  has_json :settings, schema: { restricts_access: true, max_invites: 10, greeting: "Hello!", beta: :boolean }
end

class SchematizedJsonTest < ActiveModel::TestCase
  setup do
    @account = Account.new
  end

  test "boolean" do
    assert @account.settings.restricts_access?

    @account.settings.restricts_access = false
    assert_not @account.settings.restricts_access?

    @account.settings.restricts_access = "true"
    assert @account.settings.restricts_access?
  end

  test "boolean without default" do
    assert_nil @account.settings.beta
    assert_not @account.settings.beta?
  end

  test "integer" do
    assert_equal 10, @account.settings.max_invites

    @account.settings.max_invites = 15
    assert_equal 15, @account.settings.max_invites

    @account.settings.max_invites = "100"
    assert_equal 100, @account.settings.max_invites
  end

  test "string" do
    assert_equal "Hello!", @account.settings.greeting
    @account.settings.greeting = 100
    assert_equal "100", @account.settings.greeting
  end
end
