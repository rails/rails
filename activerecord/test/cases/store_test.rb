require 'cases/helper'
require 'models/admin'
require 'models/admin/user'

class StoreTest < ActiveRecord::TestCase
  setup do
    @john = Admin::User.create(:name => 'John Doe', :color => 'black', :remember_login => true)
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
end
