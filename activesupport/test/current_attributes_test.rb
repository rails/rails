require "abstract_unit"
require "active_support/current_attributes"

Person = Struct.new(:name, :time_zone)

class Current < ActiveSupport::CurrentAttributes
  attribute :world, :account, :person

  resets { Time.zone = "UTC" }

  def account=(account)
    attributes[:account] = account
    self.person = "#{account}'s person"
  end

  def person=(person)
    attributes[:person] = person
    Time.zone = person.try(:time_zone)
  end

  def person
    "#{attributes[:person]} something"
  end
end

class CurrentAttributesTest < ActiveSupport::TestCase
  setup { Current.reset }

  test "read and write attribute" do
    Current.world = "world/1"
    assert_equal "world/1", Current.world
  end

  test "read overwritten attribute method" do
    Current.person = "person/1"
    assert_equal "person/1 something", Current.person
  end

  test "set attribute via overwritten method" do
    Current.account = "account/1"
    assert_equal "account/1", Current.account
    assert_equal "account/1's person something", Current.person
  end

  test "set auxiliary class via overwritten method" do
    Current.person = Person.new("David", "Central Time (US & Canada)")
    assert_equal "Central Time (US & Canada)", Time.zone.name
  end

  test "resets auxiliary class via callback" do
    Current.person = Person.new("David", "Central Time (US & Canada)")
    assert_equal "Central Time (US & Canada)", Time.zone.name

    Current.reset
    assert_equal "UTC", Time.zone.name
  end

  test "expose attribute only via scope" do
    Current.world = "world/1"

    Current.expose(world: "world/2") do
      assert_equal "world/2", Current.world
    end

    assert_equal "world/1", Current.world
  end

  test "expose multiple attributes" do
    Current.world = "world/1"
    Current.account = "account/1"

    Current.expose(world: "world/2", account: "account/2") do
      assert_equal "world/2", Current.world
      assert_equal "account/2", Current.account
    end

    assert_equal "world/1", Current.world
    assert_equal "account/1", Current.account
  end
end
