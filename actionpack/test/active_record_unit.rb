require  File.dirname(__FILE__) + '/abstract_unit'

# Define the essentials
class ActiveRecordTestConnector
  cattr_accessor :able_to_connect
  cattr_accessor :connected
  
  # Set our defaults
  self.connected = false
  self.able_to_connect = true
end

# Try to grab AR
begin
  PATH_TO_AR = File.dirname(__FILE__) + '/../../activerecord'
  require "#{PATH_TO_AR}/lib/active_record" unless Object.const_defined?(:ActiveRecord)
  require "#{PATH_TO_AR}/lib/active_record/fixtures" unless Object.const_defined?(:Fixtures)
rescue Object => e
  $stderr.puts "\nSkipping ActiveRecord assertion tests: #{e}"
  ActiveRecordTestConnector.able_to_connect = false
end

# Define the rest of the connector
class ActiveRecordTestConnector  
  def self.setup
    unless self.connected || !self.able_to_connect
      setup_connection
      load_schema
      self.connected = true
    end
  rescue Object => e
    $stderr.puts "\nSkipping ActiveRecord assertion tests: #{e}"
    #$stderr.puts "  #{e.backtrace.join("\n  ")}\n"
    self.able_to_connect = false
  end
  
  private
  
  def self.setup_connection
    if Object.const_defined?(:ActiveRecord)
          
      begin
        ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :dbfile => ':memory:')
        ActiveRecord::Base.connection
      rescue Object
        $stderr.puts 'SQLite 3 unavailable; falling to SQLite 2.'
        ActiveRecord::Base.establish_connection(:adapter => 'sqlite', :dbfile => ':memory:')
        ActiveRecord::Base.connection
      end
    
      Object.send(:const_set, :QUOTED_TYPE, ActiveRecord::Base.connection.quote_column_name('type')) unless Object.const_defined?(:QUOTED_TYPE)
    else
      raise "Couldn't locate ActiveRecord."
    end
  end
  
  # Load actionpack sqlite tables
  def self.load_schema
    File.read(File.dirname(__FILE__) + "/fixtures/db_definitions/sqlite.sql").split(';').each do |sql|
      ActiveRecord::Base.connection.execute(sql) unless sql.blank?
    end
  end
end
  
# Test case for inheiritance  
class ActiveRecordTestCase < Test::Unit::TestCase
  # Set our fixture path
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  
  def setup
    abort_tests unless ActiveRecordTestConnector.connected = true
  end
  
  # Default so Test::Unit::TestCase doesn't complain
  def test_truth
  end
  
  private
  
  # If things go wrong, we don't want to run our test cases. We'll just define them to test nothing.
  def abort_tests
    self.class.public_instance_methods.grep(/^test./).each do |method|
      self.class.class_eval { define_method(method.to_sym){} }
    end
  end
end

ActiveRecordTestConnector.setup