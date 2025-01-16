# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/hash_with_indifferent_access"

class AttributeAssignmentTest < ActiveModel::TestCase
  class Model
    include ActiveModel::AttributeAssignment

    attr_accessor :name, :description

    def initialize(attributes = {})
      assign_attributes(attributes)
    end

    def broken_attribute=(value)
      raise ErrorFromAttributeWriter
    end

    private
      attr_writer :metadata
  end

  class ErrorFromAttributeWriter < StandardError
  end

  class ProtectedParams
    attr_accessor :permitted
    alias :permitted? :permitted

    delegate :keys, :key?, :has_key?, :empty?, to: :@parameters

    def initialize(attributes)
      @parameters = attributes.with_indifferent_access
      @permitted = false
    end

    def permit!
      @permitted = true
      self
    end

    def [](key)
      @parameters[key]
    end

    def to_h
      @parameters
    end

    def each_pair(&block)
      @parameters.each_pair(&block)
    end

    def dup
      super.tap do |duplicate|
        duplicate.instance_variable_set :@permitted, permitted?
      end
    end
  end

  test "simple assignment" do
    model = Model.new

    model.assign_attributes(name: "hello", description: "world")
    assert_equal "hello", model.name
    assert_equal "world", model.description
  end

  test "simple assignment alias" do
    model = Model.new

    model.attributes = { name: "hello", description: "world" }
    assert_equal "hello", model.name
    assert_equal "world", model.description
  end

  test "assign non-existing attribute" do
    model = Model.new
    error = assert_raises(ActiveModel::UnknownAttributeError) do
      model.assign_attributes(hz: 1)
    end

    assert_equal model, error.record
    assert_equal "hz", error.attribute
  end

  test "assign non-existing attribute by overriding #attribute_writer_missing" do
    model_class = Class.new(Model) do
      attr_accessor :assigned_attributes

      def attribute_writer_missing(name, value) = @assigned_attributes[name] = value
    end
    model = model_class.new(assigned_attributes: {})

    model.assign_attributes unknown: "attribute"

    assert_equal({ "unknown" => "attribute" }, model.assigned_attributes)
  end

  test "assign private attribute" do
    model = Model.new
    assert_raises(ActiveModel::UnknownAttributeError) do
      model.assign_attributes(metadata: { a: 1 })
    end
  end

  test "does not swallow errors raised in an attribute writer" do
    assert_raises(ErrorFromAttributeWriter) do
      Model.new(broken_attribute: 1)
    end
  end

  test "an ArgumentError is raised if a non-hash-like object is passed" do
    err = assert_raises(ArgumentError) do
      Model.new(1)
    end

    assert_equal("When assigning attributes, you must pass a hash as an argument, Integer passed.", err.message)
  end

  test "forbidden attributes cannot be used for mass assignment" do
    params = ProtectedParams.new(name: "Guille", description: "m")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Model.new(params)
    end
  end

  test "permitted attributes can be used for mass assignment" do
    params = ProtectedParams.new(name: "Guille", description: "desc")
    params.permit!
    model = Model.new(params)

    assert_equal "Guille", model.name
    assert_equal "desc", model.description
  end

  test "regular hash should still be used for mass assignment" do
    model = Model.new(name: "Guille", description: "m")

    assert_equal "Guille", model.name
    assert_equal "m", model.description
  end

  test "assigning no attributes should not raise, even if the hash is un-permitted" do
    model = Model.new
    assert_nil model.assign_attributes(ProtectedParams.new({}))
  end

  test "passing an object with each_pair but without each" do
    model = Model.new
    h = { name: "hello", description: "world" }
    h.instance_eval { undef :each }
    model.assign_attributes(h)

    assert_equal "hello", model.name
    assert_equal "world", model.description
  end
end
