require 'cases/helper'
require 'action_dispatch'
require 'active_record/session_store'

module ActiveRecord
  class SessionStore
    class SessionTest < ActiveRecord::TestCase
      self.use_transactional_fixtures = false

      def setup
        super
        ActiveRecord::Base.connection.schema_cache.clear!
        Session.drop_table! if Session.table_exists?
      end

      def test_data_column_name
        # default column name is 'data'
        assert_equal 'data', Session.data_column_name
      end

      def test_table_name
        assert_equal 'sessions', Session.table_name
      end

      def test_accessible_attributes
        assert Session.accessible_attributes.include?(:session_id)
        assert Session.accessible_attributes.include?(:data)
        assert Session.accessible_attributes.include?(:marshaled_data)
      end

      def test_create_table!
        assert !Session.table_exists?
        Session.create_table!
        assert Session.table_exists?
        Session.drop_table!
        assert !Session.table_exists?
      end

      def test_find_by_sess_id_compat
        Session.reset_column_information
        klass = Class.new(Session) do
          def self.session_id_column
            'sessid'
          end
        end
        klass.create_table!

        assert klass.columns_hash['sessid'], 'sessid column exists'
        session = klass.new(:data => 'hello')
        session.sessid = "100"
        session.save!

        found = klass.find_by_session_id("100")
        assert_equal session, found
        assert_equal session.sessid, found.session_id
      ensure
        klass.drop_table!
        Session.reset_column_information
      end

      def test_find_by_session_id
        Session.create_table!
        session_id = "10"
        s = Session.create!(:data => 'world', :session_id => session_id)
        t = Session.find_by_session_id(session_id)
        assert_equal s, t
        assert_equal s.data, t.data
        Session.drop_table!
      end

      def test_loaded?
        Session.create_table!
        s = Session.new
        assert !s.loaded?, 'session is not loaded'
      end
    end
  end
end
