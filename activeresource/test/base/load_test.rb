require "#{File.dirname(__FILE__)}/../abstract_unit"
require "fixtures/person"
require "fixtures/street_address"

class BaseLoadTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }
    @addys = [{ :id => 1, :street => '12345 Street' }, { :id => 2, :street => '67890 Street' }]
    @deep  = { :id => 1, :street => {
      :id => 1, :state => { :id => 1, :name => 'Oregon',
        :notable_rivers => [{ :id => 1, :name => 'Willamette' },
          { :id => 2, :name => 'Columbia', :rafted_by => @matz }] }}}

    @person = Person.new
  end

  def test_load_nil
    assert_nothing_raised do
      assert_equal @person, @person.load(nil)
    end
  end

  def test_load_simple_hash
    assert_equal Hash.new, @person.attributes
    assert_equal @matz.stringify_keys, @person.load(@matz).attributes
  end

  def test_load_one_with_existing_resource
    address = @person.load(:street_address => @addys.first).street_address
    assert_kind_of StreetAddress, address
    assert_equal @addys.first.stringify_keys, address.attributes
  end

  def test_load_one_with_unknown_resource
    address = silence_warnings { @person.load(:address => @addys.first).address }
    assert_kind_of Person::Address, address
    assert_equal @addys.first.stringify_keys, address.attributes
  end

  def test_load_collection_with_existing_resource
    addresses = @person.load(:street_addresses => @addys).street_addresses
    addresses.each { |address| assert_kind_of StreetAddress, address }
    assert_equal @addys.map(&:stringify_keys), addresses.map(&:attributes)
  end

  def test_load_collection_with_unknown_resource
    assert !Person.const_defined?(:Address), "Address shouldn't exist until autocreated"
    addresses = silence_warnings { @person.load(:addresses => @addys).addresses }
    assert Person.const_defined?(:Address), "Address should have been autocreated"
    addresses.each { |address| assert_kind_of Person::Address, address }
    assert_equal @addys.map(&:stringify_keys), addresses.map(&:attributes)
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
    assert_kind_of Person::Street::State::NotableRiver, rivers.first
    assert_equal @deep[:street][:state][:notable_rivers].first[:id], rivers.first.id
    assert_equal @matz[:id], rivers.last.rafted_by.id
  end
end
