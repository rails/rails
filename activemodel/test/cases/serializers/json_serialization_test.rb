# frozen_string_literal: true

require "cases/helper"
require "models/contact"
require "models/address"
require "active_support/core_ext/object/instance_variables"

class JsonSerializationTest < ActiveModel::TestCase
  def setup
    @contact = Contact.new
    @contact.name = "Konata Izumi"
    @contact.address = Address.new(address_line: "Cantonment Road", city: "Trichy", state: "Tamil Nadu", country: "India")
    @contact.age = 16
    @contact.created_at = Time.utc(2006, 8, 1)
    @contact.awesome = true
    @contact.preferences = { "shows" => "anime" }
  end

  test "should not include root in JSON (class method)" do
    json = @contact.to_json

    assert_no_match %r{^\{"contact":\{}, json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should include root in JSON if include_root_in_json is true" do
    original_include_root_in_json = Contact.include_root_in_json
    Contact.include_root_in_json = true
    json = @contact.to_json

    assert_match %r{^\{"contact":\{}, json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  ensure
    Contact.include_root_in_json = original_include_root_in_json
  end

  test "should include root in JSON (option) even if the default is set to false" do
    json = @contact.to_json(root: true)

    assert_match %r{^\{"contact":\{}, json
  end

  test "should not include root in JSON (option)" do
    json = @contact.to_json(root: false)

    assert_no_match %r{^\{"contact":\{}, json
  end

  test "should include custom root in JSON" do
    json = @contact.to_json(root: "json_contact")

    assert_match %r{^\{"json_contact":\{}, json
    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should encode all encodable attributes" do
    json = @contact.to_json

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should allow attribute filtering with only" do
    json = @contact.to_json(only: [:name, :age])

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_no_match %r{"awesome":true}, json
    assert_not_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_no_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should allow attribute filtering with except" do
    json = @contact.to_json(except: [:name, :age])

    assert_no_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{"age":16}, json
    assert_match %r{"awesome":true}, json
    assert_includes json, %("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))})
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "methods are called on object" do
    # Define methods on fixture.
    def @contact.label; "Has cheezburger"; end
    def @contact.favorite_quote; "Constraints are liberating"; end

    # Single method.
    assert_match %r{"label":"Has cheezburger"}, @contact.to_json(only: :name, methods: :label)

    # Both methods.
    methods_json = @contact.to_json(only: :name, methods: [:label, :favorite_quote])
    assert_match %r{"label":"Has cheezburger"}, methods_json
    assert_match %r{"favorite_quote":"Constraints are liberating"}, methods_json
  end

  test "should return Hash for errors" do
    contact = Contact.new
    contact.errors.add :name, "can't be blank"
    contact.errors.add :name, "is too short (minimum is 2 characters)"
    contact.errors.add :age, "must be 16 or over"

    hash = {}
    hash[:name] = ["can't be blank", "is too short (minimum is 2 characters)"]
    hash[:age]  = ["must be 16 or over"]
    assert_equal hash.to_json, contact.errors.to_json
  end

  test "serializable_hash should not modify options passed in argument" do
    options = { except: :name }
    @contact.serializable_hash(options)

    assert_nil options[:only]
    assert_equal :name, options[:except]
  end

  test "as_json should serialize timestamps" do
    assert_equal "2006-08-01T00:00:00.000Z", @contact.as_json["created_at"]
  end

  test "as_json should return a hash if include_root_in_json is true" do
    original_include_root_in_json = Contact.include_root_in_json
    Contact.include_root_in_json = true
    json = @contact.as_json

    assert_kind_of Hash, json
    assert_kind_of Hash, json["contact"]
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json["contact"][field]
    end
  ensure
    Contact.include_root_in_json = original_include_root_in_json
  end

  test "as_json should work with root option set to true" do
    json = @contact.as_json(root: true)

    assert_kind_of Hash, json
    assert_kind_of Hash, json["contact"]
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json["contact"][field]
    end
  end

  test "as_json should work with root option set to string" do
    json = @contact.as_json(root: "connection")

    assert_kind_of Hash, json
    assert_kind_of Hash, json["connection"]
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json["connection"][field]
    end
  end

  test "as_json should allow attribute filtering with except" do
    json = @contact.as_json(except: [:age, :created_at, :awesome, :preferences])

    assert_kind_of Hash, json
    assert_equal({ "name" => "Konata Izumi" }, json)
  end

  test "as_json should allow attribute filtering with only" do
    json = @contact.as_json(only: :name)

    assert_kind_of Hash, json
    assert_equal({ "name" => "Konata Izumi" }, json)
  end

  test "as_json should work with methods options" do
    json = @contact.as_json(methods: :social)

    assert_kind_of Hash, json
    %w(name age created_at awesome preferences social).each do |field|
      assert_equal @contact.public_send(field).as_json, json[field]
    end
  end

  test "as_json should work with include option" do
    json = @contact.as_json(include: :address)

    assert_kind_of Hash, json
    assert_kind_of Hash, json["address"]
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json[field]
    end
    %w(address_line city state country).each do |field|
      assert_equal @contact.address.public_send(field).as_json, json["address"][field]
    end
  end

  test "as_json should work with include option paired with only filter" do
    json = @contact.as_json(include: { address: { only: :city } })

    assert_kind_of Hash, json
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json[field]
    end
    assert_equal({ "city" => "Trichy" }, json["address"])
  end

  test "as_json should work with include option paired with except filter" do
    json = @contact.as_json(include: { address: { except: [:address_line, :state, :country] } })

    assert_kind_of Hash, json
    %w(name age created_at awesome preferences).each do |field|
      assert_equal @contact.public_send(field).as_json, json[field]
    end
    assert_equal({ "city" => "Trichy" }, json["address"])
  end

  test "from_json should work without a root (class attribute)" do
    json = @contact.to_json
    result = Contact.new.from_json(json)

    assert_equal result.name, @contact.name
    assert_equal result.age, @contact.age
    assert_equal Time.parse(result.created_at), @contact.created_at
    assert_equal result.awesome, @contact.awesome
    assert_equal result.preferences, @contact.preferences
  end

  test "from_json should work without a root (method parameter)" do
    json = @contact.to_json
    result = Contact.new.from_json(json, false)

    assert_equal result.name, @contact.name
    assert_equal result.age, @contact.age
    assert_equal Time.parse(result.created_at), @contact.created_at
    assert_equal result.awesome, @contact.awesome
    assert_equal result.preferences, @contact.preferences
  end

  test "from_json should work with a root (method parameter)" do
    json = @contact.to_json(root: :true)
    result = Contact.new.from_json(json, true)

    assert_equal result.name, @contact.name
    assert_equal result.age, @contact.age
    assert_equal Time.parse(result.created_at), @contact.created_at
    assert_equal result.awesome, @contact.awesome
    assert_equal result.preferences, @contact.preferences
  end

  test "custom as_json should be honored when generating json" do
    def @contact.as_json(options = nil); { name: name, created_at: created_at }; end
    json = @contact.to_json

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}}, json
    assert_no_match %r{"awesome":}, json
    assert_no_match %r{"preferences":}, json
  end

  test "custom as_json options should be extensible" do
    def @contact.as_json(options = {}); super(options.merge(only: [:name])); end
    json = @contact.to_json

    assert_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{"created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}}, json
    assert_no_match %r{"awesome":}, json
    assert_no_match %r{"preferences":}, json
  end

  test "Class.model_name should be JSON encodable" do
    assert_match %r{"Contact"}, Contact.model_name.to_json
  end
end
