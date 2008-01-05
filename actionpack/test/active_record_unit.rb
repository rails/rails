require 'abstract_unit'

# Define the essentials
class ActiveRecordTestConnector
  cattr_accessor :able_to_connect
  cattr_accessor :connected

  # Set our defaults
  self.connected = false
  self.able_to_connect = true
end

# Try to grab AR
if defined?(ActiveRecord) && defined?(Fixtures)
  $stderr.puts 'Active Record is already loaded, running tests'
else
  $stderr.print 'Attempting to load Active Record... '
  begin
    PATH_TO_AR = "#{File.dirname(__FILE__)}/../../activerecord/lib"
    raise LoadError, "#{PATH_TO_AR} doesn't exist" unless File.directory?(PATH_TO_AR)
    $LOAD_PATH.unshift PATH_TO_AR
    require 'active_record'
    require 'active_record/fixtures'
    $stderr.puts 'success'
  rescue LoadError => e
    $stderr.print "failed. Skipping Active Record assertion tests: #{e}"
    ActiveRecordTestConnector.able_to_connect = false
  end
end
$stderr.flush



# Define the rest of the connector
class ActiveRecordTestConnector
  class << self
    def setup
      unless self.connected || !self.able_to_connect
        setup_connection
        load_schema
        require_fixture_models
        self.connected = true
      end
    rescue Exception => e  # errors from ActiveRecord setup
      $stderr.puts "\nSkipping ActiveRecord assertion tests: #{e}"
      #$stderr.puts "  #{e.backtrace.join("\n  ")}\n"
      self.able_to_connect = false
    end

    private

    def setup_connection
      if Object.const_defined?(:ActiveRecord)
        defaults = { :database => ':memory:' }
        begin
          options = defaults.merge :adapter => 'sqlite3', :timeout => 500
          ActiveRecord::Base.establish_connection(options)
          ActiveRecord::Base.configurations = { 'sqlite3_ar_integration' => options }
          ActiveRecord::Base.connection
        rescue Exception  # errors from establishing a connection
          $stderr.puts 'SQLite 3 unavailable; trying SQLite 2.'
          options = defaults.merge :adapter => 'sqlite'
          ActiveRecord::Base.establish_connection(options)
          ActiveRecord::Base.configurations = { 'sqlite2_ar_integration' => options }
          ActiveRecord::Base.connection
        end

        Object.send(:const_set, :QUOTED_TYPE, ActiveRecord::Base.connection.quote_column_name('type')) unless Object.const_defined?(:QUOTED_TYPE)
      else
        raise "Can't setup connection since ActiveRecord isn't loaded."
      end
    end

    # Load actionpack sqlite tables
    def load_schema
      File.read(File.dirname(__FILE__) + "/fixtures/db_definitions/sqlite.sql").split(';').each do |sql|
        ActiveRecord::Base.connection.execute(sql) unless sql.blank?
      end
    end

    def require_fixture_models
      Dir.glob(File.dirname(__FILE__) + "/fixtures/*.rb").each {|f| require f}
    end
  end
end

class ActiveRecordTestCase < ActiveSupport::TestCase
  # Set our fixture path
  if ActiveRecordTestConnector.able_to_connect
    self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
    self.use_transactional_fixtures = false
  end

  def self.fixtures(*args)
    super if ActiveRecordTestConnector.connected
  end

  def run(*args)
    super if ActiveRecordTestConnector.connected
  end

  def default_test; end
end

ActiveRecordTestConnector.setup
