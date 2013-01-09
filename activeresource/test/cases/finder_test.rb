require 'abstract_unit'
require "fixtures/person"
require "fixtures/customer"
require "fixtures/street_address"
require "fixtures/beast"
require "fixtures/proxy"
require 'active_support/core_ext/hash/conversions'

class FinderTest < Test::Unit::TestCase
  def setup
    # TODO: refactor/DRY this setup - it's a copy of the BaseTest setup.
    # We can probably put this into abstract_unit
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

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/1.xml",                {}, @matz
      mock.get    "/people/2.xml",                {}, @david
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
      mock.get    "/people/2/addresses.xml",      {}, nil, 404
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

  def test_find_by_id
    matz = Person.find(1)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
    assert matz.name?
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

  def test_all
    all = Person.all
    assert_equal 2, all.size
    assert_kind_of Person, all.first
    assert_equal "Matz", all.first.name
    assert_equal "David", all.last.name
  end

  def test_all_with_params
    all = StreetAddress.all(:params => { :person_id => 1 })
    assert_equal 1, all.size
    assert_kind_of StreetAddress, all.first
  end

  def test_find_first
    matz = Person.find(:first)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_first
    matz = Person.first
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_first_with_params
    addy = StreetAddress.first(:params => { :person_id => 1 })
    assert_kind_of StreetAddress, addy
    assert_equal '12345 Street', addy.street
  end

  def test_find_last
    david = Person.find(:last)
    assert_kind_of Person, david
    assert_equal 'David', david.name
  end

  def test_last
    david = Person.last
    assert_kind_of Person, david
    assert_equal 'David', david.name
  end

  def test_last_with_params
    addy = StreetAddress.last(:params => { :person_id => 1 })
    assert_kind_of StreetAddress, addy
    assert_equal '12345 Street', addy.street
  end

  def test_find_by_id_not_found
    assert_raise(ActiveResource::ResourceNotFound) { Person.find(99) }
    assert_raise(ActiveResource::ResourceNotFound) { StreetAddress.find(1) }
  end

  def test_find_all_sub_objects
    all = StreetAddress.find(:all, :params => { :person_id => 1 })
    assert_equal 1, all.size
    assert_kind_of StreetAddress, all.first
  end

  def test_find_all_sub_objects_not_found
    assert_nothing_raised do
      addys = StreetAddress.find(:all, :params => { :person_id => 2 })
    end
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
end
