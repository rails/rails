require 'cases/helper'
require 'models/admin'
require 'models/admin/user'

class StoreTest < ActiveRecord::TestCase
  setup do
    @john = Admin::User.create(:name => 'John Doe', :color => 'black', :remember_login => true, :height => 'tall', :is_a_good_guy => true)
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

  test "updating the store will mark it as changed" do
    @john.color = 'red'
    assert @john.settings_changed?
  end

  test "object initialization with not nullable column" do
    assert_equal true, @john.remember_login
  end

  test "writing with not nullable column" do
    @john.remember_login = false
    assert_equal false, @john.remember_login
  end

  test "reading store attributes through accessors stored as JSON" do
    assert_equal 'tall', @john.height
    assert_nil @john.weight
  end

  test "writing store attributes through accessors stored as JSON" do
    @john.height = 'short'
    @john.weight = 'heavy'

    assert_equal 'short', @john.height
    assert_equal 'heavy', @john.weight
  end

  test "accessing attributes not exposed by accessors stored as JSON" do
    @john.json_data['somestuff'] = 'somecoolstuff'
    @john.save

    assert_equal 'somecoolstuff', @john.reload.json_data['somestuff']
  end

  test "updating the store will mark it as changed stored as JSON" do
    @john.height = 'short'
    assert @john.json_data_changed?
  end

  test "object initialization with not nullable column stored as JSON" do
    assert_equal true, @john.is_a_good_guy
  end

  test "writing with not nullable column stored as JSON" do
    @john.is_a_good_guy = false
    assert_equal false, @john.is_a_good_guy
  end
end
