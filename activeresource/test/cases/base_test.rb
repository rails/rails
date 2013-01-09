require 'abstract_unit'
require "fixtures/person"
require "fixtures/customer"
require "fixtures/street_address"
require "fixtures/sound"
require "fixtures/beast"
require "fixtures/proxy"
require "fixtures/address"
require "fixtures/subscription_plan"
require 'active_support/json'
require 'active_support/ordered_hash'
require 'active_support/core_ext/hash/conversions'
require 'mocha/setup'

class BaseTest < Test::Unit::TestCase
  def setup
    setup_response # find me in abstract_unit
    @original_person_site = Person.site
  end

  def teardown
    Person.site = @original_person_site
  end

  ########################################################################
  # Tests relating to setting up the API-connection configuration
  ########################################################################

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

  def test_proxy_accessor_accepts_uri_or_string_argument
    proxy = URI.parse('http://localhost')

    assert_nothing_raised { Person.proxy = 'http://localhost' }
    assert_equal proxy, Person.proxy

    assert_nothing_raised { Person.proxy = proxy }
    assert_equal proxy, Person.proxy
  end

  def test_should_use_proxy_prefix_and_credentials
    assert_equal 'http://user:password@proxy.local:3000', ProxyResource.proxy.to_s
  end

  def test_proxy_variable_can_be_reset
    actor = Class.new(ActiveResource::Base)
    assert_nil actor.site
    actor.proxy = 'http://localhost:31337'
    actor.proxy = nil
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

  def test_should_accept_setting_auth_type
    Forum.auth_type = :digest
    assert_equal(:digest, Forum.auth_type)
    assert_equal(:digest, Forum.connection.auth_type)
  end

  def test_should_accept_setting_timeout
    Forum.timeout = 5
    assert_equal(5, Forum.timeout)
    assert_equal(5, Forum.connection.timeout)
  end

  def test_should_accept_setting_ssl_options
    expected = {:verify => 1}
    Forum.ssl_options= expected
    assert_equal(expected, Forum.ssl_options)
    assert_equal(expected, Forum.connection.ssl_options)
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

  def test_ssl_options_hash_can_be_reset
    actor = Class.new(ActiveResource::Base)
    actor.site = 'https://cinema'
    assert_nil actor.ssl_options
    actor.ssl_options = {:foo => 5}
    actor.ssl_options = nil
    assert_nil actor.ssl_options
    assert_nil actor.connection.ssl_options
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

  def test_proxy_reader_uses_superclass_site_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.proxy
    assert_nil Class.new(ActiveResource::Base).proxy

    # Subclass uses superclass proxy.
    actor = Class.new(Person)
    assert_equal Person.proxy, actor.proxy

    # Subclass returns frozen superclass copy.
    assert !Person.proxy.frozen?
    assert actor.proxy.frozen?

    # Changing subclass proxy doesn't change superclass site.
    actor.proxy = 'http://localhost:31337'
    assert_not_equal Person.proxy, actor.proxy

    # Changed subclass proxy is not frozen.
    assert !actor.proxy.frozen?

    # Changing superclass proxy doesn't overwrite subclass site.
    Person.proxy = 'http://somewhere.else'
    assert_not_equal Person.proxy, actor.proxy

    # Changing superclass proxy after subclassing changes subclass site.
    jester = Class.new(actor)
    actor.proxy = 'http://nomad'
    assert_equal actor.proxy, jester.proxy
    assert jester.proxy.frozen?

    # Subclasses are always equal to superclass proxy when not overridden
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.proxy = 'http://market'
    assert_equal fruit.proxy, apple.proxy, 'subclass did not adopt changes from parent class'

    fruit.proxy = 'http://supermarket'
    assert_equal fruit.proxy, apple.proxy, 'subclass did not adopt changes from parent class'
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

  def test_ssl_options_reader_uses_superclass_ssl_options_until_written
    # Superclass is Object so returns nil.
    assert_nil ActiveResource::Base.ssl_options
    assert_nil Class.new(ActiveResource::Base).ssl_options
    Person.ssl_options = {:foo => 'bar'}

    # Subclass uses superclass ssl_options.
    actor = Class.new(Person)
    assert_equal Person.ssl_options, actor.ssl_options

    # Changing subclass ssl_options doesn't change superclass ssl_options.
    actor.ssl_options = {:baz => ''}
    assert_not_equal Person.ssl_options, actor.ssl_options

    # Changing superclass ssl_options doesn't overwrite subclass ssl_options.
    Person.ssl_options = {:color => 'blue'}
    assert_not_equal Person.ssl_options, actor.ssl_options

    # Changing superclass ssl_options after subclassing changes subclass ssl_options.
    jester = Class.new(actor)
    actor.ssl_options = {:color => 'red'}
    assert_equal actor.ssl_options, jester.ssl_options

    # Subclasses are always equal to superclass ssl_options when not overridden.
    fruit = Class.new(ActiveResource::Base)
    apple = Class.new(fruit)

    fruit.ssl_options = {:alpha => 'betas'}
    assert_equal fruit.ssl_options, apple.ssl_options, 'subclass did not adopt changes from parent class'

    fruit.ssl_options = {:omega => 'moos'}
    assert_equal fruit.ssl_options, apple.ssl_options, 'subclass did not adopt changes from parent class'
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


  ########################################################################
  # Tests for setting up remote URLs for a given model (including adding
  # parameters appropriately)
  ########################################################################
  def test_collection_name
    assert_equal "people", Person.collection_name
  end

  def test_collection_path
    assert_equal '/people.json', Person.collection_path
  end

  def test_collection_path_with_parameters
    assert_equal '/people.json?gender=male', Person.collection_path(:gender => 'male')
    assert_equal '/people.json?gender=false', Person.collection_path(:gender => false)
    assert_equal '/people.json?gender=', Person.collection_path(:gender => nil)

    assert_equal '/people.json?gender=male', Person.collection_path('gender' => 'male')

    # Use includes? because ordering of param hash is not guaranteed
    assert Person.collection_path(:gender => 'male', :student => true).include?('/people.json?')
    assert Person.collection_path(:gender => 'male', :student => true).include?('gender=male')
    assert Person.collection_path(:gender => 'male', :student => true).include?('student=true')

    assert_equal '/people.json?name%5B%5D=bob&name%5B%5D=your+uncle%2Bme&name%5B%5D=&name%5B%5D=false', Person.collection_path(:name => ['bob', 'your uncle+me', nil, false])

    assert_equal '/people.json?struct%5Ba%5D%5B%5D=2&struct%5Ba%5D%5B%5D=1&struct%5Bb%5D=fred', Person.collection_path(:struct => ActiveSupport::OrderedHash[:a, [2,1], 'b', 'fred'])
  end

  def test_custom_element_path
    assert_equal '/people/1/addresses/1.json', StreetAddress.element_path(1, :person_id => 1)
    assert_equal '/people/1/addresses/1.json', StreetAddress.element_path(1, 'person_id' => 1)
    assert_equal '/people/Greg/addresses/1.json', StreetAddress.element_path(1, 'person_id' => 'Greg')
    assert_equal '/people/ann%20mary/addresses/ann%20mary.json', StreetAddress.element_path(:'ann mary', 'person_id' => 'ann mary')
  end

  def test_custom_element_path_without_required_prefix_param
    assert_raise ActiveResource::MissingPrefixParam do
      StreetAddress.element_path(1)
    end
  end

  def test_module_element_path
    assert_equal '/sounds/1.json', Asset::Sound.element_path(1)
  end

  def test_custom_element_path_with_redefined_to_param
    Person.module_eval do
      alias_method :original_to_param_element_path, :to_param
       def to_param
         name
       end
    end

    # Class method.
    assert_equal '/people/Greg.json', Person.element_path('Greg')

    # Protected Instance method.
    assert_equal '/people/Greg.json', Person.find('Greg').send(:element_path)

    ensure
      # revert back to original
      Person.module_eval do
        # save the 'new' to_param so we don't get a warning about discarding the method
        alias_method :element_path_to_param, :to_param
        alias_method :to_param, :original_to_param_element_path
      end
  end

  def test_custom_element_path_with_parameters
    assert_equal '/people/1/addresses/1.json?type=work', StreetAddress.element_path(1, :person_id => 1, :type => 'work')
    assert_equal '/people/1/addresses/1.json?type=work', StreetAddress.element_path(1, 'person_id' => 1, :type => 'work')
    assert_equal '/people/1/addresses/1.json?type=work', StreetAddress.element_path(1, :type => 'work', :person_id => 1)
    assert_equal '/people/1/addresses/1.json?type%5B%5D=work&type%5B%5D=play+time', StreetAddress.element_path(1, :person_id => 1, :type => ['work', 'play time'])
  end

  def test_custom_element_path_with_prefix_and_parameters
    assert_equal '/people/1/addresses/1.json?type=work', StreetAddress.element_path(1, {:person_id => 1}, {:type => 'work'})
  end

  def test_custom_collection_path_without_required_prefix_param
    assert_raise ActiveResource::MissingPrefixParam do
      StreetAddress.collection_path
    end
  end

  def test_custom_collection_path
    assert_equal '/people/1/addresses.json', StreetAddress.collection_path(:person_id => 1)
    assert_equal '/people/1/addresses.json', StreetAddress.collection_path('person_id' => 1)
  end

  def test_custom_collection_path_with_parameters
    assert_equal '/people/1/addresses.json?type=work', StreetAddress.collection_path(:person_id => 1, :type => 'work')
    assert_equal '/people/1/addresses.json?type=work', StreetAddress.collection_path('person_id' => 1, :type => 'work')
  end

  def test_custom_collection_path_with_prefix_and_parameters
    assert_equal '/people/1/addresses.json?type=work', StreetAddress.collection_path({:person_id => 1}, {:type => 'work'})
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
      person_class.prefix = "the_prefix/:the_param1/other_prefix/:the_param2"
      assert_equal Set.new([:the_param2, :the_param1]), person_class.prefix_parameters
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


  ########################################################################
  # Tests basic CRUD functions (find/save/create etc)
  ########################################################################
  def test_respond_to
    matz = Person.find(1)
    assert_respond_to matz, :name
    assert_respond_to matz, :name=
    assert_respond_to matz, :name?
    assert !matz.respond_to?(:super_scalable_stuff)
  end

  def test_custom_header
    Person.headers['key'] = 'value'
    assert_raise(ActiveResource::ResourceNotFound) { Person.find(4) }
  ensure
    Person.headers.delete('key')
  end

  def test_save
    rick = Person.new
    assert rick.save
    assert_equal '5', rick.id
  end

  def test_save!
    rick = Person.new
    assert rick.save!
    assert_equal '5', rick.id
  end

  def test_id_from_response
    p = Person.new
    resp = {'Location' => '/foo/bar/1'}
    assert_equal '1', p.__send__(:id_from_response, resp)

    resp['Location'] << '.json'
    assert_equal '1', p.__send__(:id_from_response, resp)
  end

  def test_id_from_response_without_location
    p = Person.new
    resp = {}
    assert_nil p.__send__(:id_from_response, resp)
  end

  def test_not_persisted_with_no_body_and_positive_content_length
    resp = ActiveResource::Response.new(nil)
    resp['Content-Length'] = "100"
    Person.connection.expects(:post).returns(resp)
    assert !Person.create.persisted?
  end

  def test_not_persisted_with_body_and_zero_content_length
    resp = ActiveResource::Response.new(@rick)
    resp['Content-Length'] = "0"
    Person.connection.expects(:post).returns(resp)
    assert !Person.create.persisted?
  end

  # These response codes aren't allowed to have bodies per HTTP spec
  def test_not_persisted_with_empty_response_codes
    [100,101,204,304].each do |status_code|
      resp = ActiveResource::Response.new(@rick, status_code)
      Person.connection.expects(:post).returns(resp)
      assert !Person.create.persisted?
    end
  end

  # Content-Length is not required by HTTP 1.1, so we should read
  # the body anyway in its absence.
  def test_persisted_with_no_content_length
    resp = ActiveResource::Response.new(@rick)
    resp['Content-Length'] = nil
    Person.connection.expects(:post).returns(resp)
    assert Person.create.persisted?
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
      mock.post   "/people.json", {}, nil, 409
    end
    assert_raise(ActiveResource::ResourceConflict) { Person.create(:name => 'Rick') }
  end

  def test_create_without_location
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/people.json", {}, nil, 201
    end
    person = Person.create(:name => 'Rick')
    assert_nil person.id
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
    assert_raise(NoMethodError) {matz_c.address}
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
      mock.get "/people/2.json", {}, @david
      mock.put "/people/2.json", @default_request_headers, nil, 409
    end
    assert_raise(ActiveResource::ResourceConflict) { Person.find(2).save }
  end


  ######
  # update_attribute(s)(!)

  def test_update_attribute_as_symbol
    matz = Person.first
    matz.expects(:save).returns(true)

    assert_equal "Matz", matz.name
    assert matz.update_attribute(:name, "David")
    assert_equal "David", matz.name
  end

  def test_update_attribute_as_string
    matz = Person.first
    matz.expects(:save).returns(true)

    assert_equal "Matz", matz.name
    assert matz.update_attribute('name', "David")
    assert_equal "David", matz.name
  end


  def test_update_attributes_as_symbols
    addy = StreetAddress.first(:params => {:person_id => 1})
    addy.expects(:save).returns(true)

    assert_equal "12345 Street", addy.street
    assert_equal "Australia", addy.country
    assert addy.update_attributes(:street => '54321 Street', :country => 'USA')
    assert_equal "54321 Street", addy.street
    assert_equal "USA", addy.country
  end

  def test_update_attributes_as_strings
    addy = StreetAddress.first(:params => {:person_id => 1})
    addy.expects(:save).returns(true)

    assert_equal "12345 Street", addy.street
    assert_equal "Australia", addy.country
    assert addy.update_attributes('street' => '54321 Street', 'country' => 'USA')
    assert_equal "54321 Street", addy.street
    assert_equal "USA", addy.country
  end


  #####
  # Mayhem and destruction

  def test_destroy
    assert Person.find(1).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, nil, 404
    end
    assert_raise(ActiveResource::ResourceNotFound) { Person.find(1).destroy }
  end

  def test_destroy_with_custom_prefix
    assert StreetAddress.find(1, :params => { :person_id => 1 }).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1/addresses/1.json", {}, nil, 404
    end
    assert_raise(ActiveResource::ResourceNotFound) { StreetAddress.find(1, :params => { :person_id => 1 }) }
  end

  def test_destroy_with_410_gone
    assert Person.find(1).destroy
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, nil, 410
    end
    assert_raise(ActiveResource::ResourceGone) { Person.find(1).destroy }
  end

  def test_delete
    assert Person.delete(1)
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, nil, 404
    end
    assert_raise(ActiveResource::ResourceNotFound) { Person.find(1) }
  end

  def test_delete_with_custom_prefix
    assert StreetAddress.delete(1, :person_id => 1)
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1/addresses/1.json", {}, nil, 404
    end
    assert_raise(ActiveResource::ResourceNotFound) { StreetAddress.find(1, :params => { :person_id => 1 }) }
  end

  def test_delete_with_410_gone
    assert Person.delete(1)
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, nil, 410
    end
    assert_raise(ActiveResource::ResourceGone) { Person.find(1) }
  end

  ########################################################################
  # Tests the more miscellaneous helper methods
  ########################################################################
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

  def test_exists_without_http_mock
    http = Net::HTTP.new(Person.site.host, Person.site.port)
    ActiveResource::Connection.any_instance.expects(:http).returns(http)
    http.expects(:request).returns(ActiveResource::Response.new(""))

    assert Person.exists?('not-mocked')
  end

  def test_exists_with_410_gone
    ActiveResource::HttpMock.respond_to do |mock|
      mock.head "/people/1.json", {}, nil, 410
    end

    assert !Person.exists?(1)
  end

  def test_to_xml
    Person.format = :xml
    matz = Person.find(1)
    encode = matz.encode
    xml = matz.to_xml

    assert_equal encode, xml
    assert xml.include?('<?xml version="1.0" encoding="UTF-8"?>')
    assert xml.include?('<name>Matz</name>')
    assert xml.include?('<id type="integer">1</id>')
  ensure
    Person.format = :json
  end

  def test_to_xml_with_element_name
    Person.format = :xml
    old_elem_name = Person.element_name
    matz = Person.find(1)
    Person.element_name = 'ruby_creator'
    encode = matz.encode
    xml = matz.to_xml

    assert_equal encode, xml
    assert xml.include?('<?xml version="1.0" encoding="UTF-8"?>')
    assert xml.include?('<ruby-creator>')
    assert xml.include?('<name>Matz</name>')
    assert xml.include?('<id type="integer">1</id>')
    assert xml.include?('</ruby-creator>')
  ensure
    Person.format = :json
    Person.element_name = old_elem_name
  end

  def test_to_xml_with_private_method_name_as_attribute
    Person.format = :xml

    customer = Customer.new(:foo => "foo")
    customer.singleton_class.class_eval do
      def foo
        "bar"
      end
      private :foo
    end

    assert !customer.to_xml.include?("<foo>bar</foo>")
    assert customer.to_xml.include?("<foo>foo</foo>")
  ensure
    Person.format = :json
  end

  def test_to_json
    Person.include_root_in_json = true
    joe = Person.find(6)
    encode = joe.encode
    json = joe.to_json

    assert_equal encode, json
    assert_match %r{^\{"person":\{}, json
    assert_match %r{"id":6}, json
    assert_match %r{"name":"Joe"}, json
    assert_match %r{\}\}$}, json
  end

  def test_to_json_with_element_name
    old_elem_name = Person.element_name
    Person.include_root_in_json = true
    joe = Person.find(6)
    Person.element_name = 'ruby_creator'
    encode = joe.encode
    json = joe.to_json

    assert_equal encode, json
    assert_match %r{^\{"ruby_creator":\{}, json
    assert_match %r{"id":6}, json
    assert_match %r{"name":"Joe"}, json
    assert_match %r{\}\}$}, json
  ensure
    Person.element_name = old_elem_name
  end

  def test_to_param_quacks_like_active_record
    new_person = Person.new
    assert_nil new_person.to_param
    matz = Person.find(1)
    assert_equal '1', matz.to_param
  end

  def test_to_key_quacks_like_active_record
    new_person = Person.new
    assert_nil new_person.to_key
    matz = Person.find(1)
    assert_equal [1], matz.to_key
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

  def test_with_custom_formatter
    addresses = [{ :id => "1", :street => "1 Infinite Loop", :city => "Cupertino", :state => "CA" }].to_xml(:root => :addresses)

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/addresses.xml", {}, addresses, 200
    end

    # late bind the site
    AddressResource.site = "http://localhost"
    addresses = AddressResource.find(:all)

    assert_equal "Cupertino, CA", addresses.first.city_state
  end

  def test_create_with_custom_primary_key
    silver_plan = { :plan => { :code => "silver", :price => 5.00 } }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/plans.json", {}, silver_plan, 201, 'Location' => '/plans/silver.json'
    end

    plan = SubscriptionPlan.new(:code => "silver", :price => 5.00)
    assert plan.new?

    plan.save!
    assert !plan.new?
  end

  def test_update_with_custom_primary_key
    silver_plan = { :plan => { :code => "silver", :price => 5.00 } }.to_json
    silver_plan_updated = { :plan => { :code => "silver", :price => 10.00 } }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/plans/silver.json", {}, silver_plan
      mock.put "/plans/silver.json", {}, silver_plan_updated, 201, 'Location' => '/plans/silver.json'
    end

    plan = SubscriptionPlan.find("silver")
    assert !plan.new?
    assert_equal 5.00, plan.price

    # update price
    plan.price = 10.00
    plan.save!
    assert_equal 10.00, plan.price
  end

  def test_namespacing
    sound = Asset::Sound.find(1)
    assert_equal "Asset::Sound::Author", sound.author.class.to_s
  end
end
