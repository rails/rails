require 'abstract_unit'
require 'fixtures/customer'

class AggregationsTest < Test::Unit::TestCase
  fixtures :customers

  def test_find_single_value_object
    assert_equal 50, @david.balance.amount
    assert_kind_of Money, @david.balance
    assert_equal 300, @david.balance.exchange_to("DKK").amount
  end
  
  def test_find_multiple_value_object
    assert_equal @customers["david"]["address_street"], @david.address.street
    assert(
      @david.address.close_to?(Address.new("Different Street", @customers["david"]["address_city"], @customers["david"]["address_country"]))
    )
  end
  
  def test_change_single_value_object
    @david.balance = Money.new(100)
    @david.save
    assert_equal 100, Customer.find(1).balance.amount
  end
  
  def test_immutable_value_objects
    @david.balance = Money.new(100)
    assert_raises(TypeError) {  @david.balance.instance_eval { @amount = 20 } }
  end  
  
  def test_inferred_mapping
    assert_equal "35.544623640962634", @david.gps_location.latitude
    assert_equal "-105.9309951055148", @david.gps_location.longitude
    
    @david.gps_location = GpsLocation.new("39x-110")

    assert_equal "39", @david.gps_location.latitude
    assert_equal "-110", @david.gps_location.longitude
    
    @david.save
    
    @david.reload

    assert_equal "39", @david.gps_location.latitude
    assert_equal "-110", @david.gps_location.longitude
  end
end