require 'abstract_unit'
# require File.dirname(__FILE__) + '/../dev-utils/eval_debugger'
require 'fixtures/customer'

class AggregationsTest < Test::Unit::TestCase
  def setup
    @customers = create_fixtures "customers"
    @david = Customer.find(1)
  end

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
end