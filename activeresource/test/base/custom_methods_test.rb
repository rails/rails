require "#{File.dirname(__FILE__)}/../abstract_unit"
require "#{File.dirname(__FILE__)}/../fixtures/person"
require "#{File.dirname(__FILE__)}/../fixtures/street_address"

class CustomMethodsTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    @matz_deep  = { :id => 1, :name => 'Matz', :other => 'other' }.to_xml(:root => 'person')
    @matz_array = [{ :id => 1, :name => 'Matz' }].to_xml(:root => 'people')
    @ryan  = { :name => 'Ryan' }.to_xml(:root => 'person')
    @addy  = { :id => 1, :street => '12345 Street' }.to_xml(:root => 'address')
    @addy_deep  = { :id => 1, :street => '12345 Street', :zip => "27519" }.to_xml(:root => 'address')
    @default_request_headers = { 'Content-Type' => 'application/xml' }
    
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.xml",             {}, @matz
      mock.get    "/people/1/shallow.xml", {}, @matz
      mock.get    "/people/1/deep.xml", {}, @matz_deep
      mock.get    "/people/retrieve.xml?name=Matz", {}, @matz_array
      mock.get    "/people/managers.xml", {}, @matz_array
      mock.post   "/people/hire.xml?name=Matz", {}, nil, 201
      mock.put    "/people/1/promote.xml?position=Manager", {}, nil, 204
      mock.put    "/people/promote.xml?name=Matz", {}, nil, 204, {}
      mock.put    "/people/sort.xml?by=name", {}, nil, 204
      mock.delete "/people/deactivate.xml?name=Matz", {}, nil, 200
      mock.delete "/people/1/deactivate.xml", {}, nil, 200
      mock.post   "/people/new/register.xml",      {}, @ryan, 201, 'Location' => '/people/5.xml'
      mock.post   "/people/1/register.xml", {}, @matz, 201
      mock.get    "/people/1/addresses/1.xml", {}, @addy
      mock.get    "/people/1/addresses/1/deep.xml", {}, @addy_deep
      mock.put    "/people/1/addresses/1/normalize_phone.xml?locale=US", {}, nil, 204
      mock.put    "/people/1/addresses/sort.xml?by=name", {}, nil, 204
      mock.post   "/people/1/addresses/new/link.xml", {}, { :street => '12345 Street' }.to_xml(:root => 'address'), 201, 'Location' => '/people/1/addresses/2.xml'
    end
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
    assert_equal ActiveResource::Response.new(@ryan, 201, {'Location' => '/people/5.xml'}), ryan.post(:register)

    # Test POST against a nested collection URL
    addy = StreetAddress.new(:street => '123 Test Dr.', :person_id => 1)
    assert_equal ActiveResource::Response.new({ :street => '12345 Street' }.to_xml(:root => 'address'), 
                   201, {'Location' => '/people/1/addresses/2.xml'}),
                 addy.post(:link)

    matz = Person.new(:id => 1, :name => 'Matz')
    assert_equal ActiveResource::Response.new(@matz, 201), matz.post(:register)
  end

  def test_find_custom_resources
    assert_equal 'Matz', Person.find(:all, :from => :managers).first.name
  end
end
