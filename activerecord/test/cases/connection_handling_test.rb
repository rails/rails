require 'cases/helper'

module ActiveRecord
  class ConnectionHandlingTest < ActiveRecord::TestCase
    def setup
      @parent = Class.new(Base)
      @child = Class.new(Base)

      @child.share_connection(@parent)
    end

    def test_share_connection
      assert_not_nil @parent.connection
      assert_same @child.connection, @parent.connection
    end
  end
end
