require 'cases/helper'
require 'models/admin'
require 'models/admin/user'

class StoreTest < ActiveRecord::TestCase
  fixtures :'admin/users'

  setup do
    @john = Admin::User.create!(:name => 'John Doe', :color => 'black', :remember_login => true, :height => 'tall', :is_a_good_guy => true)
  end

  test "reading store attributes through accessors" do
    assert_equal 'black', @john.color
    assert_nil @john.homepage
  end

  test "writing store attributes through accessors" do
    @john.color = 'red'
    @john.homepage = '37signals.com'

    assert_equal 'red', @john.color
    assert_equal '37signals.com', @john.homepage
  end

  test "accessing attributes not exposed by accessors" do
    @john.settings[:icecream] = 'graeters'
    @john.save

    assert_equal 'graeters', @john.reload.settings[:icecream]
  end

  test "overriding a read accessor" do
    @john.settings[:phone_number] = '1234567890'

    assert_equal '(123) 456-7890', @john.phone_number
  end

  test "updating the store will mark it as changed" do
    @john.color = 'red'
    assert @john.settings_changed?
  end

  test "updating the store populates the changed array correctly" do
    @john.color = 'red'
    assert_equal 'black', @john.settings_change[0]['color']
    assert_equal 'red', @john.settings_change[1]['color']
  end

  test "updating the store won't mark it as changed if an attribute isn't changed" do
    @john.color = @john.color
    assert !@john.settings_changed?
  end

  test "object initialization with not nullable column" do
    assert_equal true, @john.remember_login
  end

  test "writing with not nullable column" do
    @john.remember_login = false
    assert_equal false, @john.remember_login
  end

  test "overriding a write accessor" do
    @john.phone_number = '(123) 456-7890'

    assert_equal '1234567890', @john.settings[:phone_number]
  end

  test "preserve store attributes data in HashWithIndifferentAccess format without any conversion" do
    @john.json_data = HashWithIndifferentAccess.new(:height => 'tall', 'weight' => 'heavy')
    @john.height = 'low'
    assert_equal true, @john.json_data.instance_of?(HashWithIndifferentAccess)
    assert_equal 'low', @john.json_data[:height]
    assert_equal 'low', @john.json_data['height']
    assert_equal 'heavy', @john.json_data[:weight]
    assert_equal 'heavy', @john.json_data['weight']
  end

  test "convert store attributes from Hash to HashWithIndifferentAccess saving the data and access attributes indifferently" do
    user = Admin::User.find_by_name('Jamis')
    assert_equal 'symbol',  user.settings[:symbol]
    assert_equal 'symbol',  user.settings['symbol']
    assert_equal 'string',  user.settings[:string]
    assert_equal 'string',  user.settings['string']
    assert_equal true,      user.settings.instance_of?(ActiveSupport::HashWithIndifferentAccess)

    user.height = 'low'
    assert_equal 'symbol',  user.settings[:symbol]
    assert_equal 'symbol',  user.settings['symbol']
    assert_equal 'string',  user.settings[:string]
    assert_equal 'string',  user.settings['string']
    assert_equal true,      user.settings.instance_of?(ActiveSupport::HashWithIndifferentAccess)
  end

  test "convert store attributes from any format other than Hash or HashWithIndifferent access losing the data" do
    @john.json_data = "somedata"
    @john.height = 'low'
    assert_equal true, @john.json_data.instance_of?(HashWithIndifferentAccess)
    assert_equal 'low', @john.json_data[:height]
    assert_equal 'low', @john.json_data['height']
    assert_equal false, @john.json_data.delete_if { |k, v| k == 'height' }.any?
  end

  test "reading store attributes through accessors encoded with JSON" do
    assert_equal 'tall', @john.height
    assert_nil @john.weight
  end

  test "writing store attributes through accessors encoded with JSON" do
    @john.height = 'short'
    @john.weight = 'heavy'

    assert_equal 'short', @john.height
    assert_equal 'heavy', @john.weight
  end

  test "accessing attributes not exposed by accessors encoded with JSON" do
    @john.json_data['somestuff'] = 'somecoolstuff'
    @john.save

    assert_equal 'somecoolstuff', @john.reload.json_data['somestuff']
  end

  test "updating the store will mark it as changed encoded with JSON" do
    @john.height = 'short'
    assert @john.json_data_changed?
  end

  test "object initialization with not nullable column encoded with JSON" do
    assert_equal true, @john.is_a_good_guy
  end

  test "writing with not nullable column encoded with JSON" do
    @john.is_a_good_guy = false
    assert_equal false, @john.is_a_good_guy
  end

  test "all stored attributes are returned" do
    assert_equal [:color, :homepage, :favorite_food, :phone_number], Admin::User.stored_attributes[:settings]
  end

  test "stores_attributes are class level settings" do
    assert_raise(NoMethodError) { @john.stored_attributes = Hash.new }
    assert_raise(NoMethodError) { @john.stored_attributes }
  end

end
