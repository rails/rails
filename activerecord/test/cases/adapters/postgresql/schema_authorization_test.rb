require "cases/helper"

class SchemaThing < ActiveRecord::Base
end

class SchemaAuthorizationTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  TABLE_NAME = 'schema_things'
  COLUMNS = [
    'id serial primary key',
    'name character varying(50)'
  ]
  USERS = ['rails_pg_schema_user1', 'rails_pg_schema_user2']

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "SET search_path TO '$user',public"
    set_session_auth
    USERS.each do |u|
      @connection.execute "CREATE USER #{u}" rescue nil
      @connection.execute "CREATE SCHEMA AUTHORIZATION #{u}" rescue nil
      set_session_auth u
      @connection.execute "CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
      @connection.execute "INSERT INTO #{TABLE_NAME} (name) VALUES ('#{u}')"
      set_session_auth
    end
  end

  def teardown
    set_session_auth
    @connection.execute "RESET search_path"
    USERS.each do |u|
      @connection.execute "DROP SCHEMA #{u} CASCADE"
      @connection.execute "DROP USER #{u}"
    end
  end

  def test_schema_invisible
    assert_raise(ActiveRecord::StatementInvalid) do
      set_session_auth
      @connection.execute "SELECT * FROM #{TABLE_NAME}"
    end
  end

  def test_session_auth=
    assert_raise(ActiveRecord::StatementInvalid) do
      @connection.session_auth = 'DEFAULT'
      @connection.execute "SELECT * FROM #{TABLE_NAME}"
    end
  end

  def test_setting_auth_clears_stmt_cache
    assert_nothing_raised do
      set_session_auth
      USERS.each do |u|
        set_session_auth u
        assert_equal u, @connection.exec_query("SELECT name FROM #{TABLE_NAME} WHERE id = $1", 'SQL', [[nil, 1]]).first['name']
        set_session_auth
      end
    end
  end

  def test_auth_with_bind
    assert_nothing_raised do
      set_session_auth
      USERS.each do |u|
        @connection.clear_cache!
        set_session_auth u
        assert_equal u, @connection.exec_query("SELECT name FROM #{TABLE_NAME} WHERE id = $1", 'SQL', [[nil, 1]]).first['name']
        set_session_auth
      end
    end
  end

  def test_schema_uniqueness
    assert_nothing_raised do
      set_session_auth
      USERS.each do |u|
        set_session_auth u
        assert_equal u, @connection.select_value("SELECT name FROM #{TABLE_NAME} WHERE id = 1")
        set_session_auth
      end
    end
  end

  def test_sequence_schema_caching
    assert_nothing_raised do
      USERS.each do |u|
        set_session_auth u
        st = SchemaThing.new :name => 'TEST1'
        st.save!
        st = SchemaThing.new :id => 5, :name => 'TEST2'
        st.save!
        set_session_auth
      end
    end
  end

  def test_tables_in_current_schemas
    assert !@connection.tables.include?(TABLE_NAME)
    USERS.each do |u|
      set_session_auth u
      assert @connection.tables.include?(TABLE_NAME)
      set_session_auth
    end
  end

  private
    def set_session_auth auth = nil
       @connection.session_auth =  auth || 'default'
    end

end
