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
      mock.get    "/people/3.xml",             {'key' => 'value'}, nil, 404
      mock.put    "/people/1.xml",             {}, nil, 204
      mock.delete "/people/1.xml",             {}, nil, 200
      mock.delete "/people/2.xml",             {}, nil, 400
      mock.get    "/people/99.xml",            {}, nil, 404
      mock.post   "/people.xml",               {}, "<person><name>Rick</name><age type='integer'>25</age></person>", 201, 'Location' => '/people/5.xml'
      mock.get    "/people.xml",               {}, "<people>#{@matz}#{@david}</people>"
      mock.get    "/people/1/addresses.xml",   {}, "<addresses>#{@addy}</addresses>"
      mock.get    "/people/1/addresses/1.xml", {}, @addy
      mock.get    "/people/1/addresses/2.xml", {}, nil, 404
      mock.get    "/people/2/addresses/1.xml", {}, nil, 404
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

  def test_should_use_site_prefix_and_credentials
    assert_equal 'http://foo:bar@beast.caboo.se', Forum.site.to_s
    assert_equal 'http://foo:bar@beast.caboo.se/forums/:forum_id', Topic.site.to_s
  end

  def test_site_reader_uses_superclass_site_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.site
    assert_nil Class.new(ActiveResource::Base).site

    # Subclass uses superclass site.
    actor = Class.new(Person)
    assert_equal Person.site, actor.site

    # Subclass returns frozen superclass copy.
    assert !Person.site.frozen?
    assert actor.site.frozen?

    # Changing subclass site doesn't change superclass site.
    actor.site = 'http://localhost:31337'
    assert_not_equal Person.site, actor.site

    # Changed subclass site is not frozen.
    assert !actor.site.frozen?

    # Changing superclass site doesn't overwrite subclass site.
    Person.site = 'http://somewhere.else'
    assert_not_equal Person.site, actor.site

    # Changing superclass site after subclassing changes subclass site.
    jester = Class.new(actor)
    actor.site = 'http://nomad'
    assert_equal actor.site, jester.site
    assert jester.site.frozen?
  end

  def test_collection_name
    assert_equal "people", Person.collection_name
  end

  def test_collection_path
    assert_equal '/people.xml', Person.collection_path
  end

  def test_collection_path_with_parameters
    assert_equal '/people.xml?gender=male', Person.collection_path(:gender => 'male')
    assert_equal '/people.xml?gender=false', Person.collection_path(:gender => false)
    assert_equal '/people.xml?gender=', Person.collection_path(:gender => nil)

    assert_equal '/people.xml?gender=male', Person.collection_path('gender' => 'male')
    
    # Use includes? because ordering of param hash is not guaranteed
    assert Person.collection_path(:gender => 'male', :student => true).include?('/people.xml?')
    assert Person.collection_path(:gender => 'male', :student => true).include?('gender=male')
    assert Person.collection_path(:gender => 'male', :student => true).include?('student=true')

    assert_equal '/people.xml?name%5B%5D=bob&name%5B%5D=your+uncle%2Bme&name%5B%5D=&name%5B%5D=false', Person.collection_path(:name => ['bob', 'your uncle+me', nil, false])
    
    assert_equal '/people.xml?struct%5Ba%5D%5B%5D=2&struct%5Ba%5D%5B%5D=1&struct%5Bb%5D=fred', Person.collection_path(:struct => {:a => [2,1], 'b' => 'fred'})
  end

  def test_custom_element_path
    assert_equal '/people/1/addresses/1.xml', StreetAddress.element_path(1, :person_id => 1)
    assert_equal '/people/1/addresses/1.xml', StreetAddress.element_path(1, 'person_id' => 1)
  end

  def test_custom_element_path_with_parameters
    assert_equal '/people/1/addresses/1.xml?type=work', StreetAddress.element_path(1, :person_id => 1, :type => 'work')
    assert_equal '/people/1/addresses/1.xml?type=work', StreetAddress.element_path(1, 'person_id' => 1, :type => 'work')
    assert_equal '/people/1/addresses/1.xml?type=work', StreetAddress.element_path(1, :type => 'work', :person_id => 1)
    assert_equal '/people/1/addresses/1.xml?type%5B%5D=work&type%5B%5D=play+time', StreetAddress.element_path(1, :person_id => 1, :type => ['work', 'play time'])
  end

  def test_custom_element_path_with_prefix_and_parameters
    assert_equal '/people/1/addresses/1.xml?type=work', StreetAddress.element_path(1, {:person_id => 1}, {:type => 'work'})
  end

  def test_custom_collection_path
    assert_equal '/people/1/addresses.xml', StreetAddress.collection_path(:person_id => 1)
    assert_equal '/people/1/addresses.xml', StreetAddress.collection_path('person_id' => 1)
  end

  def test_custom_collection_path_with_parameters
    assert_equal '/people/1/addresses.xml?type=work', StreetAddress.collection_path(:person_id => 1, :type => 'work')
    assert_equal '/people/1/addresses.xml?type=work', StreetAddress.collection_path('person_id' => 1, :type => 'work')
  end

  def test_custom_collection_path_with_prefix_and_parameters
    assert_equal '/people/1/addresses.xml?type=work', StreetAddress.collection_path({:person_id => 1}, {:type => 'work'})
  end

  def test_custom_element_name
    assert_equal 'address', StreetAddress.element_name
  end

  def test_custom_collection_name
    assert_equal 'addresses', StreetAddress.collection_name
  end

  def test_prefix
    assert_equal "/", Person.prefix
    assert_equal Set.new, Person.send(:prefix_parameters)
  end
  
  def test_set_prefix
    SetterTrap.rollback_sets(Person) do |person_class|
      person_class.prefix = "the_prefix"
      assert_equal "the_prefix", person_class.prefix
    end
  end
  
  def test_set_prefix_with_inline_keys
    SetterTrap.rollback_sets(Person) do |person_class|
      person_class.prefix = "the_prefix:the_param"
      assert_equal "the_prefixthe_param_value", person_class.prefix(:the_param => "the_param_value")
    end
  end
  
  def test_set_prefix_with_default_value
    SetterTrap.rollback_sets(Person) do |person_class|
      person_class.set_prefix
      assert_equal "/", person_class.prefix
    end
  end

  def test_custom_prefix
    assert_equal '/people//', StreetAddress.prefix
    assert_equal '/people/1/', StreetAddress.prefix(:person_id => 1)
    assert_equal [:person_id].to_set, StreetAddress.send(:prefix_parameters)
  end

  def test_find_by_id
    matz = Person.find(1)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
    assert matz.name?
  end
  
  def test_respond_to
    matz = Person.find(1)
    assert matz.respond_to?(:name)
    assert matz.respond_to?(:name=)
    assert matz.respond_to?(:name?)
    assert !matz.respond_to?(:java)
  end

  def test_find_by_id_with_custom_prefix
    addy = StreetAddress.find(1, :params => { :person_id => 1 })
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

  def test_custom_header
    Person.headers['key'] = 'value'
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(3) }
  ensure
    Person.headers.delete('key')
  end

  def test_find_by_id_not_found
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(99) }
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1) }
  end

  def test_find_all_by_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.xml", {}, "<people>#{@david}</people>" }
  
    people = Person.find(:all, :from => "/companies/1/people.xml")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_from_with_options
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.xml", {}, "<people>#{@david}</people>" }
  
    people = Person.find(:all, :from => "/companies/1/people.xml")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_symbol_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/managers.xml", {}, "<people>#{@david}</people>" }
  
    people = Person.find(:all, :from => :managers)
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_single_by_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/manager.xml", {}, @david }

    david = Person.find(:one, :from => "/companies/1/manager.xml")
    assert_equal "David", david.name
  end

  def test_find_single_by_symbol_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/leader.xml", {}, @david }

    david = Person.find(:one, :from => :leader)
    assert_equal "David", david.name
  end

  def test_save
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
    matzs_house = StreetAddress.new(:person_id => 1)
    matzs_house.save
    assert_equal '5', matzs_house.id
  end

  # Test that loading a resource preserves its prefix_options.
  def test_load_preserves_prefix_options
    address = StreetAddress.find(1, :params => { :person_id => 1 })
    ryan = Person.new(:id => 1, :name => 'Ryan', :address => address)
    assert_equal address.prefix_options, ryan.address.prefix_options
  end

  def test_create
    rick = Person.create(:name => 'Rick')
    assert rick.valid?
    assert !rick.new?
    assert_equal '5', rick.id

    # test additional attribute returned on create
    assert_equal 25, rick.age
    
    # Test that save exceptions get bubbled up too
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/people.xml", {}, nil, 409
    end    
    assert_raises(ActiveResource::ResourceConflict) { Person.create(:name => 'Rick') }
  end

  def test_update
    matz = Person.find(:first)
    matz.name = "David"
    assert_kind_of Person, matz
    assert_equal "David", matz.name
    assert_equal true, matz.save
  end

  def test_update_with_custom_prefix_with_specific_id
    addy = StreetAddress.find(1, :params => { :person_id => 1 })
    addy.street = "54321 Street"
    assert_kind_of StreetAddress, addy
    assert_equal "54321 Street", addy.street
    addy.save
  end

  def test_update_with_custom_prefix_without_specific_id
    addy = StreetAddress.find(:first, :params => { :person_id => 1 })
    addy.street = "54321 Lane"
    assert_kind_of StreetAddress, addy
    assert_equal "54321 Lane", addy.street
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
    assert StreetAddress.find(1, :params => { :person_id => 1 }).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1/addresses/1.xml", {}, nil, 404
    end
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1, :params => { :person_id => 1 }) }
  end

  def test_delete
    assert Person.delete(1)
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.xml", {}, nil, 404
    end
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(1) }
  end
  
  def test_delete_with_custom_prefix
    assert StreetAddress.delete(1, :person_id => 1)
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1/addresses/1.xml", {}, nil, 404
    end
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1, :params => { :person_id => 1 }) }
  end

  def test_exists
    # Class method.
    assert !Person.exists?(nil)
    assert Person.exists?(1)
    assert !Person.exists?(99)

    # Instance method.
    assert !Person.new.exists?
    assert Person.find(1).exists?
    assert !Person.new(:id => 99).exists?

    # Nested class method.
    assert StreetAddress.exists?(1,  :params => { :person_id => 1 })
    assert !StreetAddress.exists?(1, :params => { :person_id => 2 })
    assert !StreetAddress.exists?(2, :params => { :person_id => 1 })

    # Nested instance method.
    assert StreetAddress.find(1, :params => { :person_id => 1 }).exists?
    assert !StreetAddress.new({:id => 1, :person_id => 2}).exists?
    assert !StreetAddress.new({:id => 2, :person_id => 1}).exists?
  end
  
  def test_to_xml
    matz = Person.find(1)
    assert_equal "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<person>\n  <name>Matz</name>\n  <id type=\"integer\">1</id>\n</person>\n", matz.to_xml
  end
end
