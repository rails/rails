# frozen_string_literal: true

require "cases/helper"
require "pp"
require "stringio"

module ActiveModel
  class InspectionTest < ActiveModel::TestCase
    class Person
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :age, :integer
      attribute :email, :string
      attribute :password, :string
      attribute :created_at, :datetime
    end

    class Admin < Person
    end

    setup do
      @previous_filter_attributes = Person.filter_attributes
      @previous_attributes_for_inspect = Person.attributes_for_inspect
    end

    teardown do
      Person.filter_attributes = @previous_filter_attributes
      Person.attributes_for_inspect = @previous_attributes_for_inspect
    end

    test "inspect shows all attributes by default" do
      person = Person.new(name: "Alice", age: 30, email: "alice@example.com")
      assert_equal '#<ActiveModel::InspectionTest::Person name: "Alice", age: 30, email: "alice@example.com", password: nil, created_at: nil>', person.inspect
    end

    test "inspect shows attribute values" do
      person = Person.new(name: "Bob", age: 25)
      assert_includes person.inspect, 'name: "Bob"'
      assert_includes person.inspect, "age: 25"
    end

    test "inspect truncates long strings at 50 characters" do
      long_name = "A" * 60
      person = Person.new(name: long_name)
      assert_includes person.inspect, 'name: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA..."'
    end

    test "inspect formats dates and times" do
      time = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
      person = Person.new(created_at: time)
      if time.respond_to?(:to_fs)
        assert_includes person.inspect, "created_at: \"#{time.to_fs(:inspect)}\""
      else
        assert_includes person.inspect, "created_at: \"#{time}\""
      end
    end

    test "inspect shows nil values" do
      person = Person.new
      assert_includes person.inspect, "name: nil"
      assert_includes person.inspect, "age: nil"
    end

    test "inspect with filter_attributes masks sensitive data" do
      Person.filter_attributes = [:password]
      person = Person.new(name: "Alice", password: "secret123")
      assert_includes person.inspect, "password: [FILTERED]"
      assert_not_includes person.inspect, "secret123"
    end

    test "filter_attributes affects attribute_for_inspect" do
      Person.filter_attributes = [:password]
      person = Person.new(password: "secret123")
      assert_equal "[FILTERED]", person.attribute_for_inspect(:password)
    end

    test "filter_attributes with regex" do
      Person.filter_attributes = [/pass/]
      person = Person.new(password: "secret123")
      assert_includes person.inspect, "password: [FILTERED]"
    end

    test "filter_attributes with proc" do
      Person.filter_attributes = [->(key, value) { value.reverse! if key == "password" }]
      person = Person.new(password: "secret")
      assert_includes person.inspect, 'password: "terces"'
    end

    test "filter_attributes does not filter nil values" do
      Person.filter_attributes = [:password]
      person = Person.new(password: nil)
      assert_includes person.inspect, "password: nil"
    end

    test "inspect with attributes_for_inspect limits output" do
      Person.attributes_for_inspect = [:name, :age]
      person = Person.new(name: "Alice", age: 30, email: "alice@example.com")
      assert_equal '#<ActiveModel::InspectionTest::Person name: "Alice", age: 30>', person.inspect
    end

    test "full_inspect shows all attributes regardless of attributes_for_inspect" do
      Person.attributes_for_inspect = [:name]
      person = Person.new(name: "Alice", age: 30, email: "alice@example.com")

      assert_equal '#<ActiveModel::InspectionTest::Person name: "Alice">', person.inspect
      assert_includes person.full_inspect, 'name: "Alice"'
      assert_includes person.full_inspect, "age: 30"
      assert_includes person.full_inspect, 'email: "alice@example.com"'
    end

    test "attributes_for_inspect with :all shows all attributes" do
      Person.attributes_for_inspect = :all
      person = Person.new(name: "Alice", age: 30)
      assert_includes person.inspect, 'name: "Alice"'
      assert_includes person.inspect, "age: 30"
    end

    test "pretty_print outputs nicely formatted attributes" do
      person = Person.new(name: "Alice", age: 30)
      actual = +""
      PP.pp(person, StringIO.new(actual))

      assert_includes actual, "name:"
      assert_includes actual, '"Alice"'
      assert_includes actual, "age:"
      assert_includes actual, "30"
    end

    test "pretty_print respects attributes_for_inspect" do
      Person.attributes_for_inspect = [:name]
      person = Person.new(name: "Alice", age: 30)
      actual = +""
      PP.pp(person, StringIO.new(actual))

      assert_includes actual, "name:"
      assert_not_includes actual, "age:"
    end

    test "pretty_print respects filter_attributes" do
      Person.filter_attributes = [:password]
      person = Person.new(name: "Alice", password: "secret")
      actual = +""
      PP.pp(person, StringIO.new(actual))

      assert_includes actual, "[FILTERED]"
      assert_not_includes actual, "secret"
    end

    test "subclass inherits filter_attributes" do
      Person.filter_attributes = [:password]
      admin = Admin.new(password: "admin_secret")
      assert_includes admin.inspect, "password: [FILTERED]"
    end

    test "subclass can override filter_attributes" do
      Person.filter_attributes = [:password]
      Admin.filter_attributes = []

      person = Person.new(password: "secret")
      admin = Admin.new(password: "admin_secret")

      assert_includes person.inspect, "password: [FILTERED]"
      assert_includes admin.inspect, 'password: "admin_secret"'
    ensure
      Admin.filter_attributes = nil
    end

    test "subclass inherits attributes_for_inspect" do
      Person.attributes_for_inspect = [:name]
      admin = Admin.new(name: "Admin", age: 40)
      assert_equal '#<ActiveModel::InspectionTest::Admin name: "Admin">', admin.inspect
    end

    test "custom inspect method is respected" do
      person_class = Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :name, :string

        def inspect
          "Custom: #{name}"
        end
      end

      person = person_class.new(name: "Custom Person")
      assert_equal "Custom: Custom Person", person.inspect
    end

    test "custom inspect method is respected for pretty_print" do
      person_class = Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :name, :string

        def inspect
          "Custom: #{name}"
        end
      end

      person = person_class.new(name: "Custom Person")
      actual = +""
      PP.pp(person, StringIO.new(actual))

      # When custom inspect is defined, pretty_print falls back to super
      # which uses Object's default behavior
      assert_includes actual, "Custom: Custom Person"
    end

    test "inspect handles uninitialized attributes gracefully" do
      person = Person.allocate
      assert_equal "#<ActiveModel::InspectionTest::Person not initialized>", person.inspect
    end

    test "pretty_print handles uninitialized attributes" do
      person = Person.allocate
      actual = +""
      PP.pp(person, StringIO.new(actual))
      assert_includes actual, "not initialized"
    end

    test "attribute_for_inspect with string" do
      person = Person.new(name: "Alice")
      assert_equal '"Alice"', person.attribute_for_inspect(:name)
    end

    test "attribute_for_inspect with long string truncates" do
      long_name = "A" * 60
      person = Person.new(name: long_name)
      assert_equal '"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA..."', person.attribute_for_inspect(:name)
    end

    test "attribute_for_inspect with integer" do
      person = Person.new(age: 30)
      assert_equal "30", person.attribute_for_inspect(:age)
    end

    test "attribute_for_inspect with nil" do
      person = Person.new(name: nil)
      assert_equal "nil", person.attribute_for_inspect(:name)
    end

    test "attribute_for_inspect with datetime" do
      time = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
      person = Person.new(created_at: time)
      if time.respond_to?(:to_fs)
        assert_equal "\"#{time.to_fs(:inspect)}\"", person.attribute_for_inspect(:created_at)
      else
        assert_equal "\"#{time}\"", person.attribute_for_inspect(:created_at)
      end
    end
  end
end
