require 'abstract_unit'
require "fixtures/person"
require "fixtures/customer"
require "fixtures/street_address"
require "fixtures/beast"

class BaseTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    @david = { :id => 2, :name => 'David' }.to_xml(:root => 'person')
    @greg  = { :id => 3, :name => 'Greg' }.to_xml(:root => 'person')
    @addy  = { :id => 1, :street => '12345 Street' }.to_xml(:root => 'address')
    @default_request_headers = { 'Content-Type' => 'application/xml' }
    @rick = { :name => "Rick", :age => 25 }.to_xml(:root => "person")
    @people = [{ :id => 1, :name => 'Matz' }, { :id => 2, :name => 'David' }].to_xml(:root => 'people')
    @people_david = [{ :id => 2, :name => 'David' }].to_xml(:root => 'people')
    @addresses = [{ :id => 1, :street => '12345 Street' }].to_xml(:root => 'addresses')

    # - deep nested resource -
    # - Luis (Customer)
    #   - JK (Customer::Friend)
    #     - Mateo (Customer::Friend::Brother)
    #       - Edith (Customer::Friend::Brother::Child)
    #       - Martha (Customer::Friend::Brother::Child)
    #     - Felipe (Customer::Friend::Brother)
    #       - Bryan (Customer::Friend::Brother::Child)
    #       - Luke (Customer::Friend::Brother::Child)
    #   - Eduardo (Customer::Friend)
    #     - Sebas (Customer::Friend::Brother)
    #       - Andres (Customer::Friend::Brother::Child)
    #       - Jorge (Customer::Friend::Brother::Child)
    #     - Elsa (Customer::Friend::Brother)
    #       - Natacha (Customer::Friend::Brother::Child)
    #     - Milena (Customer::Friend::Brother)
    #
    @luis = {:id => 1, :name => 'Luis',
              :friends => [{:name => 'JK',
                            :brothers => [{:name => 'Mateo',
                                           :children => [{:name => 'Edith'},{:name => 'Martha'}]},
                                          {:name => 'Felipe',
                                           :children => [{:name => 'Bryan'},{:name => 'Luke'}]}]},
                           {:name => 'Eduardo',
                            :brothers => [{:name => 'Sebas',
                                           :children => [{:name => 'Andres'},{:name => 'Jorge'}]},
                                          {:name => 'Elsa',
                                           :children => [{:name => 'Natacha'}]},
                                          {:name => 'Milena',
                                           :children => []}]}]}.to_xml(:root => 'customer')
    # - resource with yaml array of strings; for ActiveRecords using serialize :bar, Array
    @marty = <<-eof
      <?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <person>
        <id type=\"integer\">5</id>
        <name>Marty</name>
        <colors type=\"yaml\">---
      - \"red\"
      - \"green\"
      - \"blue\"
      </colors>
      </person>
    eof

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.xml",                {}, @matz
      mock.get    "/people/2.xml",                {}, @david
      mock.get    "/people/5.xml",                {}, @marty
      mock.get    "/people/Greg.xml",             {}, @greg
      mock.get    "/people/4.xml",                {'key' => 'value'}, nil, 404
      mock.put    "/people/1.xml",                {}, nil, 204
      mock.delete "/people/1.xml",                {}, nil, 200
      mock.delete "/people/2.xml",                {}, nil, 400
      mock.get    "/people/99.xml",               {}, nil, 404
      mock.post   "/people.xml",                  {}, @rick, 201, 'Location' => '/people/5.xml'
      mock.get    "/people.xml",                  {}, @people
      mock.get    "/people/1/addresses.xml",      {}, @addresses
      mock.get    "/people/1/addresses/1.xml",    {}, @addy
      mock.get    "/people/1/addresses/2.xml",    {}, nil, 404
      mock.get    "/people/2/addresses/1.xml",    {}, nil, 404
      mock.get    "/people/Greg/addresses/1.xml", {}, @addy
      mock.put    "/people/1/addresses/1.xml",    {}, nil, 204
      mock.delete "/people/1/addresses/1.xml",    {}, nil, 200
      mock.post   "/people/1/addresses.xml",      {}, nil, 201, 'Location' => '/people/1/addresses/5'
      mock.get    "/people//addresses.xml",       {}, nil, 404
      mock.get    "/people//addresses/1.xml",     {}, nil, 404
      mock.put    "/people//addresses/1.xml",     {}, nil, 404
      mock.delete "/people//addresses/1.xml",     {}, nil, 404
      mock.post   "/people//addresses.xml",       {}, nil, 404
      mock.head   "/people/1.xml",                {}, nil, 200
      mock.head   "/people/Greg.xml",             {}, nil, 200
      mock.head   "/people/99.xml",               {}, nil, 404
      mock.head   "/people/1/addresses/1.xml",    {}, nil, 200
      mock.head   "/people/1/addresses/2.xml",    {}, nil, 404
      mock.head   "/people/2/addresses/1.xml",    {}, nil, 404
      mock.head   "/people/Greg/addresses/1.xml", {}, nil, 200
      # customer
      mock.get    "/customers/1.xml",             {}, @luis
    end

    Person.user = nil
    Person.password = nil
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

  def test_site_variable_can_be_reset
    actor = Class.new(ActiveResource::Base)
    assert_nil actor.site
    actor.site = 'http://localhost:31337'
    actor.site = nil
    assert_nil actor.site
  end

  def test_should_accept_setting_user
    Forum.user = 'david'
    assert_equal('david', Forum.user)
    assert_equal('david', Forum.connection.user)
  end

  def test_should_accept_setting_password
    Forum.password = 'test123'
    assert_equal('test123', Forum.password)
    assert_equal('test123', Forum.connection.password)
  end

  def test_should_accept_setting_timeout
    Forum.timeout = 5
    assert_equal(5, Forum.timeout)
    assert_equal(5, Forum.connection.timeout)
  end

  def test_user_variable_can_be_reset
    actor = Class.new(ActiveResource::Base)
    actor.site = 'http://cinema'
    assert_nil actor.user
    actor.user = 'username'
    actor.user = nil
    assert_nil actor.user
    assert_nil actor.connection.user
  end

  def test_password_variable_can_be_reset
    actor = Class.new(ActiveResource::Base)
    actor.site = 'http://cinema'
    assert_nil actor.password
    actor.password = 'username'
    actor.password = nil
    assert_nil actor.password
    assert_nil actor.connection.password
  end

  def test_timeout_variable_can_be_reset
    actor = Class.new(ActiveResource::Base)
    actor.site = 'http://cinema'
    assert_nil actor.timeout
    actor.timeout = 5
    actor.timeout = nil
    assert_nil actor.timeout
    assert_nil actor.connection.timeout
  end

  def test_credentials_from_site_are_decoded
    actor = Class.new(ActiveResource::Base)
    actor.site = 'http://my%40email.com:%31%32%33@cinema'
    assert_equal("my@email.com", actor.user)
    assert_equal("123", actor.password)
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

    # Subclasses are always equal to superclass site when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.site = 'http://market'
    assert_equal fruit.site, apple.site, 'subclass did not adopt changes from parent class'

    fruit.site = 'http://supermarket'
    assert_equal fruit.site, apple.site, 'subclass did not adopt changes from parent class'
  end

  def test_user_reader_uses_superclass_user_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.user
    assert_nil Class.new(ActiveResource::Base).user
    Person.user = 'anonymous'

    # Subclass uses superclass user.
    actor = Class.new(Person)
    assert_equal Person.user, actor.user

    # Subclass returns frozen superclass copy.
    assert !Person.user.frozen?
    assert actor.user.frozen?

    # Changing subclass user doesn't change superclass user.
    actor.user = 'david'
    assert_not_equal Person.user, actor.user

    # Changing superclass user doesn't overwrite subclass user.
    Person.user = 'john'
    assert_not_equal Person.user, actor.user

    # Changing superclass user after subclassing changes subclass user.
    jester = Class.new(actor)
    actor.user = 'john.doe'
    assert_equal actor.user, jester.user

    # Subclasses are always equal to superclass user when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.user = 'manager'
    assert_equal fruit.user, apple.user, 'subclass did not adopt changes from parent class'

    fruit.user = 'client'
    assert_equal fruit.user, apple.user, 'subclass did not adopt changes from parent class'
  end

  def test_password_reader_uses_superclass_password_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.password
    assert_nil Class.new(ActiveResource::Base).password
    Person.password = 'my-password'

    # Subclass uses superclass password.
    actor = Class.new(Person)
    assert_equal Person.password, actor.password

    # Subclass returns frozen superclass copy.
    assert !Person.password.frozen?
    assert actor.password.frozen?

    # Changing subclass password doesn't change superclass password.
    actor.password = 'secret'
    assert_not_equal Person.password, actor.password

    # Changing superclass password doesn't overwrite subclass password.
    Person.password = 'super-secret'
    assert_not_equal Person.password, actor.password

    # Changing superclass password after subclassing changes subclass password.
    jester = Class.new(actor)
    actor.password = 'even-more-secret'
    assert_equal actor.password, jester.password

    # Subclasses are always equal to superclass password when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.password = 'mega-secret'
    assert_equal fruit.password, apple.password, 'subclass did not adopt changes from parent class'

    fruit.password = 'ok-password'
    assert_equal fruit.password, apple.password, 'subclass did not adopt changes from parent class'
  end

  def test_timeout_reader_uses_superclass_timeout_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.timeout
    assert_nil Class.new(ActiveResource::Base).timeout
    Person.timeout = 5

    # Subclass uses superclass timeout.
    actor = Class.new(Person)
    assert_equal Person.timeout, actor.timeout

    # Changing subclass timeout doesn't change superclass timeout.
    actor.timeout = 10
    assert_not_equal Person.timeout, actor.timeout

    # Changing superclass timeout doesn't overwrite subclass timeout.
    Person.timeout = 15
    assert_not_equal Person.timeout, actor.timeout

    # Changing superclass timeout after subclassing changes subclass timeout.
    jester = Class.new(actor)
    actor.timeout = 20
    assert_equal actor.timeout, jester.timeout

    # Subclasses are always equal to superclass timeout when not overridden.
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.timeout = 25
    assert_equal fruit.timeout, apple.timeout, 'subclass did not adopt changes from parent class'

    fruit.timeout = 30
    assert_equal fruit.timeout, apple.timeout, 'subclass did not adopt changes from parent class'
  end

  def test_updating_baseclass_site_object_wipes_descendent_cached_connection_objects
    # Subclasses are always equal to superclass site when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.site = 'http://market'
    assert_equal fruit.connection.site, apple.connection.site
    first_connection = apple.connection.object_id

    fruit.site = 'http://supermarket'
    assert_equal fruit.connection.site, apple.connection.site
    second_connection = apple.connection.object_id
    assert_not_equal(first_connection, second_connection, 'Connection should be re-created')
  end

  def test_updating_baseclass_user_wipes_descendent_cached_connection_objects
    # Subclasses are always equal to superclass user when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)
    fruit.site = 'http://market'

    fruit.user = 'david'
    assert_equal fruit.connection.user, apple.connection.user
    first_connection = apple.connection.object_id

    fruit.user = 'john'
    assert_equal fruit.connection.user, apple.connection.user
    second_connection = apple.connection.object_id
    assert_not_equal(first_connection, second_connection, 'Connection should be re-created')
  end

  def test_updating_baseclass_password_wipes_descendent_cached_connection_objects
    # Subclasses are always equal to superclass password when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)
    fruit.site = 'http://market'

    fruit.password = 'secret'
    assert_equal fruit.connection.password, apple.connection.password
    first_connection = apple.connection.object_id

    fruit.password = 'supersecret'
    assert_equal fruit.connection.password, apple.connection.password
    second_connection = apple.connection.object_id
    assert_not_equal(first_connection, second_connection, 'Connection should be re-created')
  end

  def test_updating_baseclass_timeout_wipes_descendent_cached_connection_objects
    # Subclasses are always equal to superclass timeout when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)
    fruit.site = 'http://market'

    fruit.timeout = 5
    assert_equal fruit.connection.timeout, apple.connection.timeout
    first_connection = apple.connection.object_id

    fruit.timeout = 10
    assert_equal fruit.connection.timeout, apple.connection.timeout
    second_connection = apple.connection.object_id
    assert_not_equal(first_connection, second_connection, 'Connection should be re-created')
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
    assert_equal '/people/Greg/addresses/1.xml', StreetAddress.element_path(1, 'person_id' => 'Greg')
  end

  def test_custom_element_path_with_redefined_to_param
    Person.module_eval do
      alias_method :original_to_param_element_path, :to_param
       def to_param
         name
       end
    end

    # Class method.
    assert_equal '/people/Greg.xml', Person.element_path('Greg')

    # Protected Instance method.
    assert_equal '/people/Greg.xml', Person.find('Greg').send(:element_path)

    ensure
      # revert back to original
      Person.module_eval do
        # save the 'new' to_param so we don't get a warning about discarding the method
        alias_method :element_path_to_param, :to_param
        alias_method :to_param, :original_to_param_element_path
      end
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
    assert_equal Set.new, Person.__send__(:prefix_parameters)
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

  def test_set_prefix_twice_should_clear_params
    SetterTrap.rollback_sets(Person) do |person_class|
      person_class.prefix = "the_prefix/:the_param1"
      assert_equal Set.new([:the_param1]), person_class.prefix_parameters
      person_class.prefix = "the_prefix/:the_param2"
      assert_equal Set.new([:the_param2]), person_class.prefix_parameters
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
    assert_equal [:person_id].to_set, StreetAddress.__send__(:prefix_parameters)
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
    assert !matz.respond_to?(:super_scalable_stuff)
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

  def test_find_last
    david = Person.find(:last)
    assert_kind_of Person, david
    assert_equal 'David', david.name
  end

  def test_custom_header
    Person.headers['key'] = 'value'
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(4) }
  ensure
    Person.headers.delete('key')
  end

  def test_find_by_id_not_found
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(99) }
    assert_raises(ActiveResource::ResourceNotFound) { StreetAddress.find(1) }
  end

  def test_find_all_by_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.xml", {}, @people_david }

    people = Person.find(:all, :from => "/companies/1/people.xml")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_from_with_options
    ActiveResource::HttpMock.respond_to { |m| m.get "/companies/1/people.xml", {}, @people_david }

    people = Person.find(:all, :from => "/companies/1/people.xml")
    assert_equal 1, people.size
    assert_equal "David", people.first.name
  end

  def test_find_all_by_symbol_from
    ActiveResource::HttpMock.respond_to { |m| m.get "/people/managers.xml", {}, @people_david }

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
    assert_equal '1', p.__send__(:id_from_response, resp)

    resp['Location'] << '.xml'
    assert_equal '1', p.__send__(:id_from_response, resp)
  end

  def test_id_from_response_without_location
    p = Person.new
    resp = {}
    assert_equal nil, p.__send__(:id_from_response, resp)
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

  def test_reload_works_with_prefix_options
    address = StreetAddress.find(1, :params => { :person_id => 1 })
    assert_equal address, address.reload
  end

  def test_reload_with_redefined_to_param
    Person.module_eval do
      alias_method :original_to_param_reload, :to_param
       def to_param
         name
       end
    end

    person = Person.find('Greg')
    assert_equal person, person.reload

    ensure
      # revert back to original
      Person.module_eval do
        # save the 'new' to_param so we don't get a warning about discarding the method
        alias_method :reload_to_param, :to_param
        alias_method :to_param, :original_to_param_reload
      end
  end

  def test_reload_works_without_prefix_options
    person = Person.find(:first)
    assert_equal person, person.reload
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

  def test_create_without_location
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/people.xml", {}, nil, 201
    end
    person = Person.create(:name => 'Rick')
    assert_equal nil, person.id
  end

  def test_clone
    matz = Person.find(1)
    matz_c = matz.clone
    assert matz_c.new?
    matz.attributes.each do |k, v|
      assert_equal v, matz_c.send(k) if k != Person.primary_key
    end
  end

  def test_nested_clone
    addy = StreetAddress.find(1, :params => {:person_id => 1})
    addy_c = addy.clone
    assert addy_c.new?
    addy.attributes.each do |k, v|
      assert_equal v, addy_c.send(k) if k != StreetAddress.primary_key
    end
    assert_equal addy.prefix_options, addy_c.prefix_options
  end

  def test_complex_clone
    matz = Person.find(1)
    matz.address = StreetAddress.find(1, :params => {:person_id => matz.id})
    matz.non_ar_hash = {:not => "an ARes instance"}
    matz.non_ar_arr = ["not", "ARes"]
    matz_c = matz.clone
    assert matz_c.new?
    assert_raises(NoMethodError) {matz_c.address}
    assert_equal matz.non_ar_hash, matz_c.non_ar_hash
    assert_equal matz.non_ar_arr, matz_c.non_ar_arr

    # Test that actual copy, not just reference copy
    matz.non_ar_hash[:not] = "changed"
    assert_not_equal matz.non_ar_hash, matz_c.non_ar_hash
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

  def test_exists_with_redefined_to_param
    Person.module_eval do
      alias_method :original_to_param_exists, :to_param
      def to_param
        name
      end
    end

    # Class method.
    assert Person.exists?('Greg')

    # Instance method.
    assert Person.find('Greg').exists?

    # Nested class method.
    assert StreetAddress.exists?(1,  :params => { :person_id => Person.find('Greg').to_param })

    # Nested instance method.
    assert StreetAddress.find(1, :params => { :person_id => Person.find('Greg').to_param }).exists?

  ensure
    # revert back to original
    Person.module_eval do
      # save the 'new' to_param so we don't get a warning about discarding the method
      alias_method :exists_to_param, :to_param
      alias_method :to_param, :original_to_param_exists
    end
  end

  def test_to_xml
    matz = Person.find(1)
    xml = matz.encode
    assert xml.starts_with?('<?xml version="1.0" encoding="UTF-8"?>')
    assert xml.include?('<name>Matz</name>')
    assert xml.include?('<id type="integer">1</id>')
  end

  def test_to_param_quacks_like_active_record
    new_person = Person.new
    assert_nil new_person.to_param
    matz = Person.find(1)
    assert_equal '1', matz.to_param
  end

  def test_parse_deep_nested_resources
    luis = Customer.find(1)
    assert_kind_of Customer, luis
    luis.friends.each do |friend|
      assert_kind_of Customer::Friend, friend
      friend.brothers.each do |brother|
        assert_kind_of Customer::Friend::Brother, brother
        brother.children.each do |child|
          assert_kind_of Customer::Friend::Brother::Child, child
        end
      end
    end
  end

  def test_load_yaml_array
    assert_nothing_raised do
      marty = Person.find(5)
      assert_equal 3, marty.colors.size
      marty.colors.each do |color|
        assert_kind_of String, color
      end
    end
  end
end
