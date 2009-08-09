require 'abstract_unit'
require "fixtures/person"
require "fixtures/street_address"

module Highrise
  class Note < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000"
  end

  class Comment < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000"
  end

  module Deeply
    module Nested

      class Note < ActiveResource::Base
        self.site = "http://37s.sunrise.i:3000"
      end

       class Comment < ActiveResource::Base
         self.site = "http://37s.sunrise.i:3000"
       end

       module TestDifferentLevels

         class Note < ActiveResource::Base
           self.site = "http://37s.sunrise.i:3000"
         end

       end

    end
  end

end


class BaseLoadTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }

    @first_address = { :id => 1, :street => '12345 Street' }
    @addresses = [@first_address, { :id => 2, :street => '67890 Street' }]
    @addresses_from_xml = { :street_addresses => @addresses }
    @addresses_from_xml_single = { :street_addresses => [ @first_address ] }

    @deep  = { :id => 1, :street => {
      :id => 1, :state => { :id => 1, :name => 'Oregon',
        :notable_rivers => [
          { :id => 1, :name => 'Willamette' },
          { :id => 2, :name => 'Columbia', :rafted_by => @matz }],
        :postal_codes => [97018,1234567890],
        :places => ["Columbia City", "Unknown"]}}}

    @person = Person.new
  end

  def test_load_expects_hash
    assert_raise(ArgumentError) { @person.load nil }
    assert_raise(ArgumentError) { @person.load '<person id="1"/>' }
  end

  def test_load_simple_hash
    assert_equal Hash.new, @person.attributes
    assert_equal @matz.stringify_keys, @person.load(@matz).attributes
  end

  def test_load_one_with_existing_resource
    address = @person.load(:street_address => @first_address).street_address
    assert_kind_of StreetAddress, address
    assert_equal @first_address.stringify_keys, address.attributes
  end

  def test_load_one_with_unknown_resource
    address = silence_warnings { @person.load(:address => @first_address).address }
    assert_kind_of Person::Address, address
    assert_equal @first_address.stringify_keys, address.attributes
  end

  def test_load_collection_with_existing_resource
    addresses = @person.load(@addresses_from_xml).street_addresses
    assert_kind_of Array, addresses
    addresses.each { |address| assert_kind_of StreetAddress, address }
    assert_equal @addresses.map(&:stringify_keys), addresses.map(&:attributes)
  end

  def test_load_collection_with_unknown_resource
    Person.__send__(:remove_const, :Address) if Person.const_defined?(:Address)
    assert !Person.const_defined?(:Address), "Address shouldn't exist until autocreated"
    addresses = silence_warnings { @person.load(:addresses => @addresses).addresses }
    assert Person.const_defined?(:Address), "Address should have been autocreated"
    addresses.each { |address| assert_kind_of Person::Address, address }
    assert_equal @addresses.map(&:stringify_keys), addresses.map(&:attributes)
  end

  def test_load_collection_with_single_existing_resource
    addresses = @person.load(@addresses_from_xml_single).street_addresses
    assert_kind_of Array, addresses
    addresses.each { |address| assert_kind_of StreetAddress, address }
    assert_equal [ @first_address ].map(&:stringify_keys), addresses.map(&:attributes)
  end

  def test_load_collection_with_single_unknown_resource
    Person.__send__(:remove_const, :Address) if Person.const_defined?(:Address)
    assert !Person.const_defined?(:Address), "Address shouldn't exist until autocreated"
    addresses = silence_warnings { @person.load(:addresses => [ @first_address ]).addresses }
    assert Person.const_defined?(:Address), "Address should have been autocreated"
    addresses.each { |address| assert_kind_of Person::Address, address }
    assert_equal [ @first_address ].map(&:stringify_keys), addresses.map(&:attributes)
  end

  def test_recursively_loaded_collections
    person = @person.load(@deep)
    assert_equal @deep[:id], person.id

    street = person.street
    assert_kind_of Person::Street, street
    assert_equal @deep[:street][:id], street.id

    state = street.state
    assert_kind_of Person::Street::State, state
    assert_equal @deep[:street][:state][:id], state.id

    rivers = state.notable_rivers
    assert_kind_of Array, rivers
    assert_kind_of Person::Street::State::NotableRiver, rivers.first
    assert_equal @deep[:street][:state][:notable_rivers].first[:id], rivers.first.id
    assert_equal @matz[:id], rivers.last.rafted_by.id

    postal_codes = state.postal_codes
    assert_kind_of Array, postal_codes
    assert_equal 2, postal_codes.size
    assert_kind_of Fixnum, postal_codes.first
    assert_equal @deep[:street][:state][:postal_codes].first, postal_codes.first
    assert_kind_of Bignum, postal_codes.last
    assert_equal @deep[:street][:state][:postal_codes].last, postal_codes.last

    places = state.places
    assert_kind_of Array, places
    assert_kind_of String, places.first
    assert_equal @deep[:street][:state][:places].first, places.first
  end
  
  def test_nested_collections_within_the_same_namespace
    n = Highrise::Note.new(:comments => [{ :name => "1" }])
    assert_kind_of Highrise::Comment, n.comments.first
  end

  def test_nested_collections_within_deeply_nested_namespace
    n = Highrise::Deeply::Nested::Note.new(:comments => [{ :name => "1" }])
    assert_kind_of Highrise::Deeply::Nested::Comment, n.comments.first
  end

  def test_nested_collections_in_different_levels_of_namespaces
    n = Highrise::Deeply::Nested::TestDifferentLevels::Note.new(:comments => [{ :name => "1" }])
    assert_kind_of Highrise::Deeply::Nested::Comment, n.comments.first
  end


end
