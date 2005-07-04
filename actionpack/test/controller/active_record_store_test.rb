# Unfurl the safety net.
path_to_ar = File.dirname(__FILE__) + '/../../../activerecord'
if Object.const_defined?(:ActiveRecord) or File.exist?(path_to_ar)
  begin

# These tests exercise CGI::Session::ActiveRecordStore, so you're going to
# need AR in a sibling directory to AP and have SQLite3 installed.

unless Object.const_defined?(:ActiveRecord)
  require "#{File.dirname(__FILE__)}/../../../activerecord/lib/active_record"
end

require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/session/active_record_store'

CGI::Session::ActiveRecordStore::Session.establish_connection(:adapter => 'sqlite3', :dbfile => ':memory:')

def setup_session_schema(connection, table_name = 'sessions', session_id_column_name = 'sessid', data_column_name = 'data')
  connection.execute <<-end_sql
    create table #{table_name} (
      id integer primary key,
      #{connection.quote_column_name(session_id_column_name)} text unique,
      #{connection.quote_column_name(data_column_name)} text
    )
  end_sql
end

class ActiveRecordStoreTest < Test::Unit::TestCase
  def session_class
    CGI::Session::ActiveRecordStore::Session
  end

  def setup
    session_class.create_table!

    ENV['REQUEST_METHOD'] = 'GET'
    CGI::Session::ActiveRecordStore.session_class = session_class

    @new_session = CGI::Session.new(CGI.new, :database_manager => CGI::Session::ActiveRecordStore, :new_session => true)
    @new_session['foo'] = 'bar'
  end

  def teardown
    session_class.drop_table!
  end

  def test_basics
    session_id = @new_session.session_id
    @new_session.close
    found = session_class.find_by_session_id(session_id)
    assert_not_nil found
    assert_equal 'bar', found.data['foo']
  end
end


class SqlBypassActiveRecordStoreTest < Test::Unit::TestCase
  def session_class
    CGI::Session::ActiveRecordStore::SqlBypass
  end

  def setup
    session_class.connection = CGI::Session::ActiveRecordStore::Session.connection
    session_class.create_table!

    ENV['REQUEST_METHOD'] = 'GET'
    CGI::Session::ActiveRecordStore.session_class = session_class

    @new_session = CGI::Session.new(CGI.new, :database_manager => CGI::Session::ActiveRecordStore, :new_session => true)
  end

  def teardown
    session_class.drop_table!
  end

  def test_basics
    session_id = @new_session.session_id
    @new_session.close
    found = session_class.find_by_session_id(session_id)
    assert_not_nil found
    assert_equal 'bar', found.data['foo']
  end
end


# End of safety net.
  rescue Object => e
    $stderr.puts "Skipping CGI::Session::ActiveRecordStore tests: #{e}"    
    #$stderr.puts "  #{e.backtrace.join("\n  ")}"
  end
end
