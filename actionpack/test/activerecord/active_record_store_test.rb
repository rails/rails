# These tests exercise CGI::Session::ActiveRecordStore, so you're going to
# need AR in a sibling directory to AP and have SQLite installed.
require File.dirname(__FILE__) + '/../active_record_unit'
require 'action_controller/session/active_record_store'


module CommonActiveRecordStoreTests
  def test_basics
    s = session_class.new(:session_id => '1234', :data => { 'foo' => 'bar' })
    assert_equal 'bar', s.data['foo']
    assert s.save
    assert_equal 'bar', s.data['foo']

    assert_not_nil t = session_class.find_by_session_id('1234')
    assert_not_nil t.data
    assert_equal 'bar', t.data['foo']
  end

  def test_reload_same_session
    @new_session.update
    reloaded = CGI::Session.new(CGI.new, 'session_id' => @new_session.session_id, 'database_manager' => CGI::Session::ActiveRecordStore)
    assert_equal 'bar', reloaded['foo']
  end

  def test_tolerates_close_close
    assert_nothing_raised do
      @new_session.close
      @new_session.close
    end
  end
end

class ActiveRecordStoreTest < ActiveRecordTestCase
  include CommonActiveRecordStoreTests

  def session_class
    CGI::Session::ActiveRecordStore::Session
  end

  def session_id_column
    "session_id"
  end

  def setup
    session_class.create_table!

    ENV['REQUEST_METHOD'] = 'GET'
    ENV['REQUEST_URI'] = '/'
    CGI::Session::ActiveRecordStore.session_class = session_class

    @cgi = CGI.new
    @new_session = CGI::Session.new(@cgi, 'database_manager' => CGI::Session::ActiveRecordStore, 'new_session' => true)
    @new_session['foo'] = 'bar'
  end

# this test only applies for eager session saving
#  def test_another_instance
#    @another = CGI::Session.new(@cgi, 'session_id' => @new_session.session_id, 'database_manager' => CGI::Session::ActiveRecordStore)
#    assert_equal @new_session.session_id, @another.session_id
#  end

  def test_model_attribute
    assert_kind_of CGI::Session::ActiveRecordStore::Session, @new_session.model
    assert_equal({ 'foo' => 'bar' }, @new_session.model.data)
  end

  def test_save_unloaded_session
    c = session_class.connection
    bogus_class = c.quote(Base64.encode64("\004\010o:\vBlammo\000"))
    c.insert("INSERT INTO #{session_class.table_name} ('#{session_id_column}', 'data') VALUES ('abcdefghijklmnop', #{bogus_class})")

    sess = session_class.find_by_session_id('abcdefghijklmnop')
    assert_not_nil sess
    assert !sess.loaded?

    # because the session is not loaded, the save should be a no-op. If it
    # isn't, this'll try and unmarshall the bogus class, and should get an error.
    assert_nothing_raised { sess.save }
  end

  def teardown
    session_class.drop_table!
  end
end

class ColumnLimitTest < ActiveRecordTestCase
  def setup
    @session_class = CGI::Session::ActiveRecordStore::Session
    @session_class.create_table!
  end

  def teardown
    @session_class.drop_table!
  end

  def test_protection_from_data_larger_than_column
    # Can't test this unless there is a limit
    return unless limit = @session_class.data_column_size_limit
    too_big = ':(' * limit
    s = @session_class.new(:session_id => '666', :data => {'foo' => too_big})
    s.data
    assert_raise(ActionController::SessionOverflowError) { s.save }
  end
end

class DeprecatedActiveRecordStoreTest < ActiveRecordStoreTest
  def session_id_column
    "sessid"
  end

  def setup
    session_class.connection.execute 'create table old_sessions (id integer primary key, sessid text unique, data text)'
    session_class.table_name = 'old_sessions'
    session_class.send :setup_sessid_compatibility!

    ENV['REQUEST_METHOD'] = 'GET'
    CGI::Session::ActiveRecordStore.session_class = session_class

    @new_session = CGI::Session.new(CGI.new, 'database_manager' => CGI::Session::ActiveRecordStore, 'new_session' => true)
    @new_session['foo'] = 'bar'
  end

  def teardown
    session_class.connection.execute 'drop table old_sessions'
    session_class.table_name = 'sessions'
  end
end

class SqlBypassActiveRecordStoreTest < ActiveRecordStoreTest
  def session_class
    unless defined? @session_class
      @session_class = CGI::Session::ActiveRecordStore::SqlBypass
      @session_class.connection = CGI::Session::ActiveRecordStore::Session.connection
    end
    @session_class
  end

  def test_model_attribute
    assert_kind_of CGI::Session::ActiveRecordStore::SqlBypass, @new_session.model
    assert_equal({ 'foo' => 'bar' }, @new_session.model.data)
  end
end
