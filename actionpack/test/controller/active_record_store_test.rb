# Unfurl the safety net.
path_to_ar = File.dirname(__FILE__) + '/../../../activerecord'
if Object.const_defined?(:ActiveRecord) or File.exist?(path_to_ar)
  begin

# These tests exercise CGI::Session::ActiveRecordStore, so you're going to
# need AR in a sibling directory to AP and have SQLite installed.

unless Object.const_defined?(:ActiveRecord)
  require File.join(path_to_ar, 'lib', 'active_record')
end

require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/session/active_record_store'

#ActiveRecord::Base.logger = Logger.new($stdout)
begin
  CGI::Session::ActiveRecordStore::Session.establish_connection(:adapter => 'sqlite3', :dbfile => ':memory:')
  CGI::Session::ActiveRecordStore::Session.connection
rescue Object
  $stderr.puts 'SQLite 3 unavailable; falling back to SQLite 2.'
  begin
    CGI::Session::ActiveRecordStore::Session.establish_connection(:adapter => 'sqlite', :dbfile => ':memory:')
    CGI::Session::ActiveRecordStore::Session.connection
  rescue Object
    $stderr.puts 'SQLite 2 unavailable; skipping ActiveRecordStore test suite.'
    raise SystemExit
  end
end


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

class ActiveRecordStoreTest < Test::Unit::TestCase
  include CommonActiveRecordStoreTests

  def session_class
    CGI::Session::ActiveRecordStore::Session
  end

  def setup
    session_class.create_table!

    ENV['REQUEST_METHOD'] = 'GET'
    CGI::Session::ActiveRecordStore.session_class = session_class

    @new_session = CGI::Session.new(CGI.new, 'database_manager' => CGI::Session::ActiveRecordStore, 'new_session' => true)
    @new_session['foo'] = 'bar'
  end

  def teardown
    session_class.drop_table!
  end
end


class DeprecatedActiveRecordStoreTest < ActiveRecordStoreTest
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
    session_class.send :setup_sessid_compatibility!
  end
end

class SqlBypassActiveRecordStoreTest < ActiveRecordStoreTest
  def session_class
    unless @session_class
      @session_class = CGI::Session::ActiveRecordStore::SqlBypass
      @session_class.connection = CGI::Session::ActiveRecordStore::Session.connection
    end
    @session_class
  end
end


# End of safety net.
  rescue Object => e
    $stderr.puts "Skipping CGI::Session::ActiveRecordStore tests: #{e}"    
    #$stderr.puts "  #{e.backtrace.join("\n  ")}"
  end
end
