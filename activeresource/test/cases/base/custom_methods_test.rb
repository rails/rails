require 'abstract_unit'
require 'fixtures/person'
require 'fixtures/street_address'
require 'active_support/core_ext/hash/conversions'

class CustomMethodsTest < ActiveSupport::TestCase
  def setup
    @matz  = { :person => { :id => 1, :name => 'Matz' } }.to_json
    @matz_deep  = { :person => { :id => 1, :name => 'Matz', :other => 'other' } }.to_json
    @matz_array = { :people => [{ :person => { :id => 1, :name => 'Matz' } }] }.to_json
    @ryan  = { :person => { :name => 'Ryan' } }.to_json
    @addy  = { :address => { :id => 1, :street => '12345 Street' } }.to_json
    @addy_deep  = { :address => { :id => 1, :street => '12345 Street', :zip => "27519" } }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.json",        {}, @matz
      mock.get    "/people/1/shallow.json", {}, @matz
      mock.get    "/people/1/deep.json", {}, @matz_deep
      mock.get    "/people/retrieve.json?name=Matz", {}, @matz_array
      mock.get    "/people/managers.json", {}, @matz_array
      mock.post   "/people/hire.json?name=Matz", {}, nil, 201
      mock.put    "/people/1/promote.json?position=Manager", {}, nil, 204
      mock.put    "/people/promote.json?name=Matz", {}, nil, 204, {}
      mock.put    "/people/sort.json?by=name", {}, nil, 204
      mock.delete "/people/deactivate.json?name=Matz", {}, nil, 200
      mock.delete "/people/1/deactivate.json", {}, nil, 200
      mock.post   "/people/new/register.json",      {}, @ryan, 201, 'Location' => '/people/5.json'
      mock.post   "/people/1/register.json", {}, @matz, 201
      mock.get    "/people/1/addresses/1.json", {}, @addy
      mock.get    "/people/1/addresses/1/deep.json", {}, @addy_deep
      mock.put    "/people/1/addresses/1/normalize_phone.json?locale=US", {}, nil, 204
      mock.put    "/people/1/addresses/sort.json?by=name", {}, nil, 204
      mock.post   "/people/1/addresses/new/link.json", {}, { :address => { :street => '12345 Street' } }.to_json, 201, 'Location' => '/people/1/addresses/2.json'
    end

    Person.user = nil
    Person.password = nil
  end

  def teardown
    ActiveResource::HttpMock.reset!
  end

  def test_custom_collection_method
    # GET
    assert_equal([{ "id" => 1, "name" => 'Matz' }], Person.get(:retrieve, :name => 'Matz'))

    # POST
    assert_equal(ActiveResource::Response.new("", 201, {}), Person.post(:hire, :name => 'Matz'))

    # PUT
    assert_equal ActiveResource::Response.new("", 204, {}),
                   Person.put(:promote, {:name => 'Matz'}, 'atestbody')
    assert_equal ActiveResource::Response.new("", 204, {}), Person.put(:sort, :by => 'name')

    # DELETE
    Person.delete :deactivate, :name => 'Matz'

    # Nested resource
    assert_equal ActiveResource::Response.new("", 204, {}), StreetAddress.put(:sort, :person_id => 1, :by => 'name')
  end

  def test_custom_element_method
    # Test GET against an element URL
    assert_equal Person.find(1).get(:shallow), {"id" => 1, "name" => 'Matz'}
    assert_equal Person.find(1).get(:deep), {"id" => 1, "name" => 'Matz', "other" => 'other'}

    # Test PUT against an element URL
    assert_equal ActiveResource::Response.new("", 204, {}), Person.find(1).put(:promote, {:position => 'Manager'}, 'body')

    # Test DELETE against an element URL
    assert_equal ActiveResource::Response.new("", 200, {}), Person.find(1).delete(:deactivate)

    # With nested resources
    assert_equal StreetAddress.find(1, :params => { :person_id => 1 }).get(:deep),
                  { "id" => 1, "street" => '12345 Street', "zip" => "27519" }
    assert_equal ActiveResource::Response.new("", 204, {}),
                   StreetAddress.find(1, :params => { :person_id => 1 }).put(:normalize_phone, :locale => 'US')
  end

  def test_custom_new_element_method
    # Test POST against a new element URL
    ryan = Person.new(:name => 'Ryan')
    assert_equal ActiveResource::Response.new(@ryan, 201, { 'Location' => '/people/5.json' }), ryan.post(:register)
    expected_request = ActiveResource::Request.new(:post, '/people/new/register.json', @ryan)
    assert_equal expected_request.body, ActiveResource::HttpMock.requests.first.body

    # Test POST against a nested collection URL
    addy = StreetAddress.new(:street => '123 Test Dr.', :person_id => 1)
    assert_equal ActiveResource::Response.new({ :address => { :street => '12345 Street' } }.to_json,
                   201, { 'Location' => '/people/1/addresses/2.json' }),
                 addy.post(:link)

    matz = Person.find(1)
    assert_equal ActiveResource::Response.new(@matz, 201), matz.post(:register)
  end

  def test_find_custom_resources
    assert_equal 'Matz', Person.find(:all, :from => :managers).first.name
  end
end
