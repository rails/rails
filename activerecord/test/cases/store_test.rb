require 'cases/helper'
require 'models/admin'
require 'models/admin/user'

class StoreTest < ActiveRecord::TestCase
  setup do
    @john = Admin::User.create(name: 'John Doe', color: 'black')
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

    assert 'graeters', @john.reload.settings[:icecream]
  end
end
