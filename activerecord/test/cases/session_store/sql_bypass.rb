require 'cases/helper'
require 'action_dispatch'
require 'active_record/session_store'

module ActiveRecord
  class SessionStore
    class SqlBypassTest < ActiveRecord::TestCase
      def setup
        super
        Session.drop_table! if Session.table_exists?
      end

      def test_create_table
        assert !Session.table_exists?
        SqlBypass.create_table!
        assert Session.table_exists?
        SqlBypass.drop_table!
        assert !Session.table_exists?
      end

      def test_new_record?
        s = SqlBypass.new :data => 'foo', :session_id => 10
        assert s.new_record?, 'this is a new record!'
      end

      def test_not_loaded?
        s = SqlBypass.new({})
        assert !s.loaded?, 'it is not loaded'
      end

      def test_loaded?
        s = SqlBypass.new :data => 'hello'
        assert s.loaded?, 'it is loaded'
      end
    end
  end
end
