# frozen_string_literal: true

require "cases/helper"

class Account
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include ActiveModel::SchematizedJson

  attribute :settings
  has_json :settings, restricts_access: true, max_invites: 10, greeting: "Hello!", beta: :boolean

  attribute :flags
  has_delegated_json :flags, premium: false

  attribute :flags_with_defaults, default: { "staff" => false, "early_adopter" => true }
  has_json :flags_with_defaults, staff: true, early_adopter: false

  attribute :broken
  has_json :broken, creation: :datetime, nesting: {}

  attribute :mutable_defaults
  has_json :mutable_defaults, greeting: +"Hello!"
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

  test "delegated accessors" do
    assert_not @account.premium?
    @account.premium = true
    assert @account.premium?
  end

  test "mass assignment" do
    @account.settings = { "restricts_access" => "false", "max_invites" => "5", "greeting" => "goodbye" }
    assert_not @account.settings.restricts_access?
    assert_equal 5, @account.settings.max_invites
    assert_equal "goodbye", @account.settings.greeting
  end

  test "schema defaults will not overwrite attribute defaults" do
    assert_not @account.flags_with_defaults.staff?
    assert @account.flags_with_defaults.early_adopter?
  end

  test "defaults are not shared between records" do
    @account.mutable_defaults.greeting << "!"
    assert_equal "Hello!", Account.new.mutable_defaults.greeting
  end

  test "reads are not a change" do
    @account.settings.max_invites
    assert_not_predicate @account, :changed?
  end

  test "writes are a change" do
    @account.settings.max_invites = 5
    assert_predicate @account, :settings_changed?
  end

  test "defaults are stored in the attribute" do
    @account.settings.max_invites
    assert_equal({ "restricts_access" => true, "max_invites" => 10, "greeting" => "Hello!", "beta" => nil }, @account.attributes["settings"])
  end

  test "mass assignment of an unknown key raises" do
    assert_raises(NoMethodError) do
      @account.settings = { "max_invites" => "5", "unknown" => "value" }
    end
  end

  test "only standard json types are acceptable schema types" do
    assert_raises(ArgumentError) do
      @account.broken.creation = DateTime.now
    end

    assert_raises(ArgumentError) do
      @account.broken.nesting = { not: :valid }
    end
  end
end
