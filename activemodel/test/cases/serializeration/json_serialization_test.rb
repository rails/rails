require 'cases/helper'
require 'models/contact'

class Contact
  include ActiveModel::Serializers::JSON

  def attributes
    instance_values
  end
end

class JsonSerializationTest < ActiveModel::TestCase
  def setup
    @contact = Contact.new
    @contact.name = 'Konata Izumi'
    @contact.age = 16
    @contact.created_at = Time.utc(2006, 8, 1)
    @contact.awesome = true
    @contact.preferences = { 'shows' => 'anime' }
  end

  test "should include root in json" do
    begin
      Contact.include_root_in_json = true
      json = @contact.to_json

      assert_match %r{^\{"contact":\{}, json
      assert_match %r{"name":"Konata Izumi"}, json
      assert_match %r{"age":16}, json
      assert json.include?(%("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
      assert_match %r{"awesome":true}, json
      assert_match %r{"preferences":\{"shows":"anime"\}}, json
    ensure
      Contact.include_root_in_json = false
    end
  end

  test "should encode all encodable attributes" do
    json = @contact.to_json

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert json.include?(%("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_match %r{"awesome":true}, json
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should allow attribute filtering with only" do
    json = @contact.to_json(:only => [:name, :age])

    assert_match %r{"name":"Konata Izumi"}, json
    assert_match %r{"age":16}, json
    assert_no_match %r{"awesome":true}, json
    assert !json.include?(%("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_no_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "should allow attribute filtering with except" do
    json = @contact.to_json(:except => [:name, :age])

    assert_no_match %r{"name":"Konata Izumi"}, json
    assert_no_match %r{"age":16}, json
    assert_match %r{"awesome":true}, json
    assert json.include?(%("created_at":#{ActiveSupport::JSON.encode(Time.utc(2006, 8, 1))}))
    assert_match %r{"preferences":\{"shows":"anime"\}}, json
  end

  test "methds are called on object" do
    # Define methods on fixture.
    def @contact.label; "Has cheezburger"; end
    def @contact.favorite_quote; "Constraints are liberating"; end

    # Single method.
    assert_match %r{"label":"Has cheezburger"}, @contact.to_json(:only => :name, :methods => :label)

    # Both methods.
    methods_json = @contact.to_json(:only => :name, :methods => [:label, :favorite_quote])
    assert_match %r{"label":"Has cheezburger"}, methods_json
    assert_match %r{"favorite_quote":"Constraints are liberating"}, methods_json
  end
end
