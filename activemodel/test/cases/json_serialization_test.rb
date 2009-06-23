require 'cases/helper'

class JsonSerializationTest < ActiveModel::TestCase
  class Contact
    extend ActiveModel::Naming
    include ActiveModel::Serializers::JSON
    attr_accessor :name, :age, :created_at, :awesome, :preferences
  end

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
end
