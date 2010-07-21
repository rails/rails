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
    end
  end
end
