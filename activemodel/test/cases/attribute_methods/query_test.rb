# frozen_string_literal: true

require "cases/helper"

class AttributeMethodsQueryTest < ActiveModel::TestCase
  class JsonType < ActiveModel::Type::Value
    def type
      :json
    end

    def deserialize(value)
      return value unless value.is_a?(::String)
      ActiveSupport::JSON.decode(value) rescue nil
    end

    def serialize(value)
      ActiveSupport::JSON.encode(value) unless value.nil?
    end
  end
  ActiveModel::Type.register(:json, JsonType)

  class TextType < ActiveModel::Type::String
    def type
      :text
    end
  end
  ActiveModel::Type.register(:text, TextType)

  class Model
    include ActiveModel::Model
    include ActiveModel::Attributes
  end

  class Developer < Model
    attribute :salary, :integer
  end

  class Topic < Model
    attribute :approved, :boolean
    attribute :author_name, :string
  end

  test "read overridden attribute with predicate respects override" do
    topic = Topic.new

    topic.approved = true

    def topic.approved; false; end

    assert_not topic.approved?, "overridden approved should be false"
  end

  test "string attribute predicate" do
    [nil, "", " "].each do |value|
      assert_equal false, Topic.new(author_name: value).author_name?
    end

    assert_equal true, Topic.new(author_name: "Name").author_name?

    ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
      assert_predicate Topic.new(author_name: value), :author_name?
    end
  end

  test "number attribute predicate" do
    [nil, 0, "0"].each do |value|
      assert_equal false, Developer.new(salary: value).salary?
    end

    assert_equal true, Developer.new(salary: 1).salary?
    assert_equal true, Developer.new(salary: "1").salary?
  end

  test "boolean attribute predicate" do
    [nil, "", false, "false", "f", 0].each do |value|
      assert_equal false, Topic.new(approved: value).approved?
    end

    [true, "true", "1", 1].each do |value|
      assert_equal true, Topic.new(approved: value).approved?
    end
  end

  test "user-defined text attribute predicate" do
    klass = Class.new(Model) do
      attribute :user_defined_text, :text
    end

    topic = klass.new(user_defined_text: "text")
    assert_predicate topic, :user_defined_text?

    ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
      topic = klass.new(user_defined_text: value)
      assert_predicate topic, :user_defined_text?
    end
  end

  test "user-defined date attribute predicate" do
    klass = Class.new(Model) do
      attribute :user_defined_date, :date
    end

    topic = klass.new(user_defined_date: Date.current)
    assert_predicate topic, :user_defined_date?
  end

  test "user-defined datetime attribute predicate" do
    klass = Class.new(Model) do
      attribute :user_defined_datetime, :datetime
    end

    topic = klass.new(user_defined_datetime: Time.current)
    assert_predicate topic, :user_defined_datetime?
  end

  test "user-defined time attribute predicate" do
    klass = Class.new(Model) do
      attribute :user_defined_time, :time
    end

    topic = klass.new(user_defined_time: Time.current)
    assert_predicate topic, :user_defined_time?
  end

  test "user-defined JSON attribute predicate" do
    klass = Class.new(Model) do
      attribute :user_defined_json, :json
    end

    topic = klass.new(user_defined_json: { key: "value" })
    assert_predicate topic, :user_defined_json?

    topic = klass.new(user_defined_json: {})
    assert_not_predicate topic, :user_defined_json?
  end
end
