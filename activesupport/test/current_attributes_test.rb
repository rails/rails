# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/current_attributes/test_helper"

class CurrentAttributesTest < ActiveSupport::TestCase
  # Automatically included in Rails apps via railtie but that dodn't run here.
  include ActiveSupport::CurrentAttributes::TestHelper

  Person = Struct.new(:id, :name, :time_zone)

  class Current < ActiveSupport::CurrentAttributes
    attribute :world, :account, :person, :request
    delegate :time_zone, to: :person

    before_reset { Session.previous = person&.id }

    resets do
      Time.zone = "UTC"
      Session.current = nil
    end

    def account=(account)
      super
      self.person = Person.new(1, "#{account}'s person")
    end

    def person=(person)
      super
      Time.zone = person&.time_zone
      Session.current = person&.id
    end

    def set_world_and_account(world:, account:)
      self.world = world
      self.account = account
    end

    def get_world_and_account(hash)
      hash[:world] = world
      hash[:account] = account
      hash
    end

    def respond_to_test; end

    def request
      "#{super} something"
    end

    def intro
      "#{person.name}, in #{time_zone}"
    end
  end

  class Session < ActiveSupport::CurrentAttributes
    attribute :current, :previous
  end

  # Eagerly set-up `instance`s by reference.
  [ Current.instance, Session.instance ]

  # Use library specific minitest hook to catch Time.zone before reset is called via TestHelper
  def before_setup
    @original_time_zone = Time.zone
    super
  end

  # Use library specific minitest hook to set Time.zone after reset is called via TestHelper
  def after_teardown
    super
    Time.zone = @original_time_zone
  end

  setup { assert_nil Session.previous, "Expected Session to not have leaked state" }

  test "read and write attribute" do
    Current.world = "world/1"
    assert_equal "world/1", Current.world
  end

  test "read overwritten attribute method" do
    Current.request = "request/1"
    assert_equal "request/1 something", Current.request
  end

  test "set attribute via overwritten method" do
    Current.account = "account/1"
    assert_equal "account/1", Current.account
    assert_equal "account/1's person", Current.person.name
  end

  test "set auxiliary class via overwritten method" do
    Current.person = Person.new(42, "David", "Central Time (US & Canada)")
    assert_equal "Central Time (US & Canada)", Time.zone.name
    assert_equal 42, Session.current
  end

  test "resets auxiliary classes via callback" do
    Current.person = Person.new(42, "David", "Central Time (US & Canada)")
    assert_equal "Central Time (US & Canada)", Time.zone.name

    Current.reset
    assert_equal "UTC", Time.zone.name
    assert_equal 42, Session.previous
    assert_nil Session.current
  end

  test "set auxiliary class based on current attributes via before callback" do
    Current.person = Person.new(42, "David", "Central Time (US & Canada)")
    assert_nil Session.previous
    assert_equal 42, Session.current

    Current.reset
    assert_equal 42, Session.previous
    assert_nil Session.current
  end

  test "set attribute only via scope" do
    Current.world = "world/1"

    Current.set(world: "world/2") do
      assert_equal "world/2", Current.world
    end

    assert_equal "world/1", Current.world
  end

  test "set multiple attributes" do
    Current.world = "world/1"
    Current.account = "account/1"

    Current.set(world: "world/2", account: "account/2") do
      assert_equal "world/2", Current.world
      assert_equal "account/2", Current.account
    end

    assert_equal "world/1", Current.world
    assert_equal "account/1", Current.account
  end

  test "using keyword arguments" do
    Current.set_world_and_account(world: "world/1", account: "account/1")

    assert_equal "world/1", Current.world
    assert_equal "account/1", Current.account

    hash = {}
    assert_same hash, Current.get_world_and_account(hash)
    assert_equal "world/1", hash[:world]
    assert_equal "account/1", hash[:account]
  end

  setup { @testing_teardown = false }
  teardown { assert_equal 42, Session.current if @testing_teardown }

  test "accessing attributes in teardown" do
    Session.current = 42
    @testing_teardown = true
  end

  test "delegation" do
    Current.person = Person.new(42, "David", "Central Time (US & Canada)")
    assert_equal "Central Time (US & Canada)", Current.time_zone
    assert_equal "Central Time (US & Canada)", Current.instance.time_zone
  end

  test "all methods forward to the instance" do
    Current.person = Person.new(42, "David", "Central Time (US & Canada)")
    assert_equal "David, in Central Time (US & Canada)", Current.intro
    assert_equal "David, in Central Time (US & Canada)", Current.instance.intro
  end

  test "respond_to? for methods that have not been called" do
    assert_equal true, Current.respond_to?("respond_to_test")
  end
end
