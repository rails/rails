require 'cases/helper'
require 'models/admin'
require 'models/admin/user'
require 'models/admin/user_with_ordered_options_store'

class StoreTest < ActiveRecord::TestCase
  setup do
    @john = Admin::User.create(:name => 'John Doe', :color => 'black')
    @jane = Admin::UserWithOrderedOptionsStore.create(:name => 'Jane Doe', :color => 'white')
  end

  test "reading store attributes through accessors" do
    assert_equal 'black', @john.color
    assert_nil @john.homepage
    assert_equal 'white', @jane.color
    assert_nil @jane.homepage
  end

  test "writing store attributes through accessors" do
    @john.color = 'red'
    @john.homepage = '37signals.com'
    @jane.color = 'green'
    @jane.homepage = 'github.com'

    assert_equal 'red', @john.color
    assert_equal '37signals.com', @john.homepage
    assert_equal 'green', @jane.color
    assert_equal 'github.com', @jane.homepage
  end

  test "accessing attributes not exposed by accessors" do
    @john.settings[:icecream] = 'graeters'
    @john.save
    @jane.settings[:icecream] = 'aglamesis'
    @jane.save

    assert_equal 'graeters', @john.reload.settings[:icecream]
    assert_equal 'aglamesis', @jane.reload.settings[:icecream]
  end

  test "updating the store will mark it as changed" do
    @john.color = 'red'
    @jane.color = 'green'
    assert @john.settings_changed?
    assert @jane.settings_changed?
  end
end
