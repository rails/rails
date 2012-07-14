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

      def test_persisted?
        s = SqlBypass.new :data => 'foo', :session_id => 10
        assert !s.persisted?, 'this is a new record!'
      end

      def test_not_loaded?
        s = SqlBypass.new({})
        assert !s.loaded?, 'it is not loaded'
      end

      def test_loaded?
        s = SqlBypass.new :data => 'hello'
        assert s.loaded?, 'it is loaded'
      end

      def test_save
        SqlBypass.create_table! unless Session.table_exists?
        session_id = 20
        s = SqlBypass.new :data => 'hello', :session_id => session_id
        s.save
        t = SqlBypass.find_by_session_id session_id
        assert_equal s.session_id, t.session_id
        assert_equal s.data, t.data
      end

      def test_destroy
        SqlBypass.create_table! unless Session.table_exists?
        session_id = 20
        s = SqlBypass.new :data => 'hello', :session_id => session_id
        s.save
        s.destroy
        assert_nil SqlBypass.find_by_session_id session_id
      end

      def test_data_column
        SqlBypass.drop_table! if exists = Session.table_exists?
        old, SqlBypass.data_column = SqlBypass.data_column, 'foo'
        SqlBypass.create_table!

        session_id = 20
        SqlBypass.new(:data => 'hello', :session_id => session_id).save
        assert_equal 'hello', SqlBypass.find_by_session_id(session_id).data
      ensure
        SqlBypass.drop_table!
        SqlBypass.data_column = old
        SqlBypass.create_table! if exists
      end
    end
  end
end
