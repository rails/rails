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

class MultiparameterAttributeAssignmentTest < ActiveModel::TestCase
  class Model
    include ActiveModel::AttributeAssignment
    include ActiveModel::Attributes

    def initialize(attributes = {})
      super()
      assign_attributes(attributes)
    end
  end

  class Customer < Model
    attribute :address

    def address=(value)
      if value.is_a?(Hash)
        street, city, country = value[1], value[2], value[3]

        super(Address.new(street, city, country))
      else
        super
      end
    end
  end

  class Address < Model
    attr_reader :street, :city, :country

    def initialize(street, city, country)
      @street, @city, @country = street, city, country
    end

    def ==(other)
      [street, city, country] == [other.street, other.city, other.country]
    end
  end

  class Topic < Model
    attribute :last_read, :date
    attribute :written_on, :datetime
    attribute :bonus_time, :time
  end

  test "multiparameter attributes on date" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "24" }

    assert_equal Date.new(2004, 6, 24), topic.last_read.to_date
  end

  test "multiparameter attributes on date with empty year" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "24" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with empty month" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "24" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with empty day" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with empty day and year" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with empty day and month" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with empty year and month" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "24" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on date with all empty" do
    topic = Topic.new
    topic.attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "" }

    assert_nil topic.last_read
  end

  test "multiparameter attributes on time" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }

    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
  end

  test "multiparameter attributes on time with no date" do
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      topic = Topic.new
      topic.attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  test "multiparameter attributes on time with invalid time params" do
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      topic = Topic.new
      topic.attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "2004", "written_on(5i)" => "36", "written_on(6i)" => "64",
      }
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  test "multiparameter attributes on time with old date" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "1850", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }

    # testing against to_fs(:db) representation because either a Time or a DateTime might be returned, depending on platform
    assert_equal "1850-06-24 16:24:00", topic.written_on.to_fs(:db)
  end

  test "multiparameter attributes on time will raise on big time if missing date parts" do
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      topic = Topic.new
      topic.attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24"
      }
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  test "multiparameter attributes on time with raise on small time if missing date parts" do
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      topic = Topic.new
      topic.attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
      }
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  test "multiparameter attributes on time will ignore hour if missing" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "12", "written_on(3i)" => "12",
      "written_on(5i)" => "12", "written_on(6i)" => "02"
    }

    assert_equal Time.utc(2004, 12, 12, 0, 12, 2), topic.written_on
  end

  test "multiparameter attributes on time will ignore hour if blank" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }

    assert_nil topic.written_on
  end

  test "multiparameter attributes on time will ignore date if empty" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "24"
    }

    assert_nil topic.written_on
  end

  test "multiparameter attributes on time with seconds will ignore date if empty" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }

    assert_nil topic.written_on
  end

  test "multiparameter attributes on time with utc" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }

    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
  end

  test "multiparameter attributes setting time attribute" do
    topic = Topic.new
    topic.attributes = { "bonus_time(4i)" => "01", "bonus_time(5i)" => "05" }

    assert_equal 1, topic.bonus_time.hour
    assert_equal 5, topic.bonus_time.min
  end

  test "multiparameter attributes on time with empty seconds" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => ""
    }

    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
  end

  test "multiparameter attributes setting date attribute" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "1952", "written_on(2i)" => "3", "written_on(3i)" => "11"
    }

    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
  end

  test "multiparameter attributes setting date and time attribute" do
    topic = Topic.new
    topic.attributes = {
      "written_on(1i)" => "1952",
      "written_on(2i)" => "3",
      "written_on(3i)" => "11",
      "written_on(4i)" => "13",
      "written_on(5i)" => "55"
    }

    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
    assert_equal 13, topic.written_on.hour
    assert_equal 55, topic.written_on.min
  end

  test "multiparameter attributes setting time but not date on date field" do
    assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      topic = Topic.new
      topic.attributes = { "written_on(4i)" => "13", "written_on(5i)" => "55" }
    end
  end

  test "multiparameter assignment of aggregation" do
    address = Address.new("The Street", "The City", "The Country")
    customer = Customer.new
    customer.attributes = { "address(1)" => address.street, "address(2)" => address.city, "address(3)" => address.country }

    assert_equal address, customer.address
  end

  test "multiparameter assignment of aggregation out of order" do
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    customer.attributes = { "address(3)" => address.country, "address(2)" => address.city, "address(1)" => address.street }

    assert_equal address, customer.address
  end

  test "multiparameter assignment of aggregation with missing values" do
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    customer.attributes = { "address(2)" => address.city, "address(3)" => address.country }

    assert_nil customer.address.street
    assert_equal address.city, customer.address.city
    assert_equal address.country, customer.address.country
  end

  test "multiparameter assignment of aggregation with blank values" do
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => "", "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes

    assert_equal Address.new(nil, "The City", "The Country"), customer.address
  end

  test "multiparameter assignment of aggregation from #initialize" do
    address = Address.new("The Street", "The City", "The Country")
    customer = Customer.new("address(1)" => address.street, "address(2)" => address.city, "address(3)" => address.country)

    assert_equal address, customer.address
  end
end
