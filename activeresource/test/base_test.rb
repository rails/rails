require "#{File.dirname(__FILE__)}/abstract_unit"
require "fixtures/person"
require "fixtures/street_address"
require "fixtures/beast"

class BaseTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    @david = { :id => 2, :name => 'David' }.to_xml(:root => 'person')
    @addy  = { :id => 1, :street => '12345 Street' }.to_xml(:root => 'address')
    @default_request_headers = { 'Content-Type' => 'application/xml' }
    
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.xml",             {}, @matz
      mock.get    "/people/2.xml",             {}, @david
      mock.put    "/people/1.xml",             {}, nil, 204
      mock.delete "/people/1.xml",             {}, nil, 200
      mock.delete "/people/2.xml",             {}, nil, 400
      mock.post   "/people.xml",               {}, nil, 201, 'Location' => '/people/5.xml'
      mock.get    "/people/99.xml",            {}, nil, 404
      mock.get    "/people.xml",               {}, "<people>#{@matz}#{@david}</people>"
      mock.get    "/people/1/addresses.xml",   {}, "<addresses>#{@addy}</addresses>"
      mock.get    "/people/1/addresses/1.xml", {}, @addy
      mock.put    "/people/1/addresses/1.xml", {}, nil, 204
      mock.delete "/people/1/addresses/1.xml", {}, nil, 200
      mock.post   "/people/1/addresses.xml",   {}, nil, 201, 'Location' => '/people/1/addresses/5'
      mock.get    "/people//addresses.xml",    {}, nil, 404
      mock.get    "/people//addresses/1.xml",  {}, nil, 404
      mock.put    "/people//addresses/1.xml",  {}, nil, 404
      mock.delete "/people//addresses/1.xml",  {}, nil, 404
      mock.post   "/people//addresses.xml",    {}, nil, 404
    end
  end


  def test_site_accessor_accepts_uri_or_string_argument
    site = URI.parse('http://localhost')

    assert_nothing_raised { Person.site = 'http://localhost' }
    assert_equal site, Person.site

    assert_nothing_raised { Person.site = site }
    assert_equal site, Person.site
  end


  def test_collection_name
    assert_equal "people", Person.collection_name
  end

  def test_collection_path
    assert_equal '/people.xml', Person.collection_path
  end

  def test_custom_element_path
    assert_equal '/people/1/addresses/1.xml', StreetAddress.element_path(1, :person_id => 1)
  end

  def test_custom_collection_path
    assert_equal '/people/1/addresses.xml', StreetAddress.collection_path(:person_id => 1)
  end

  def test_custom_element_name
    assert_equal 'address', StreetAddress.element_name
  end

  def test_custom_collection_name
    assert_equal 'addresses', StreetAddress.collection_name
  end

  def test_prefix
    assert_equal "/", Person.prefix
  end

  def test_custom_prefix
    assert_equal '/people//', StreetAddress.prefix
    assert_equal '/people/1/', StreetAddress.prefix(:person_id => 1)
  end

  def test_find_by_id
    matz = Person.find(1)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_find_by_id_with_custom_prefix
    addy = StreetAddress.find(1, :person_id => 1)
    assert_kind_of StreetAddress, addy
    assert_equal '12345 Street', addy.street
  end

  def test_find_all
    all = Person.find(:all)
    assert_equal 2, all.size
    assert_kind_of Person, all.first
    assert_equal "Matz", all.first.name
    assert_equal "David", all.last.name
  end

  def test_find_first
    matz = Person.find(:first)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_find_by_id_not_found
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(99) }
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1) }
  end

  def test_create
    rick = Person.new
    assert_equal true, rick.save
    assert_equal '5', rick.id
  end

  def test_id_from_response
    p = Person.new
    resp = {'Location' => '/foo/bar/1'}
    assert_equal '1', p.send(:id_from_response, resp)
    
    resp['Location'] << '.xml'
    assert_equal '1', p.send(:id_from_response, resp)
  end

  def test_create_with_custom_prefix
    matzs_house = StreetAddress.new({}, {:person_id => 1})
    matzs_house.save
    assert_equal '5', matzs_house.id
  end

  def test_update
    matz = Person.find(:first)
    matz.name = "David"
    assert_kind_of Person, matz
    assert_equal "David", matz.name
    assert_equal true, matz.save
  end

  def test_update_with_custom_prefix
    addy = StreetAddress.find(1, :person_id => 1)
    addy.street = "54321 Street"
    assert_kind_of StreetAddress, addy
    assert_equal "54321 Street", addy.street
    addy.save
  end

  def test_update_conflict
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/2.xml", {}, @david
      mock.put "/people/2.xml", @default_request_headers, nil, 409
    end
    assert_raises(ActiveResource::ResourceConflict) { Person.find(2).save }
  end

  def test_destroy
    assert Person.find(1).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.xml", {}, nil, 404
    end
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(1).destroy }
  end

  def test_destroy_with_custom_prefix
    assert StreetAddress.find(1, :person_id => 1).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1/addresses/1.xml", {}, nil, 404
    end
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1, :person_id => 1).destroy }
  end

  def test_delete
    assert Person.delete(1)
  end

  def test_should_use_site_prefix_and_credentials
    assert_equal 'http://foo:bar@beast.caboo.se', Forum.site.to_s
    assert_equal 'http://foo:bar@beast.caboo.se/forums/:forum_id', Topic.site.to_s
  end
end
