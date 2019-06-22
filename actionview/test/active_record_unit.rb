# frozen_string_literal: true

require "abstract_unit"

# Define the essentials
class ActiveRecordTestConnector
  cattr_accessor :able_to_connect
  cattr_accessor :connected

  # Set our defaults
  self.connected = false
  self.able_to_connect = true
end

# Try to grab AR
unless defined?(ActiveRecord) && defined?(FixtureSet)
  begin
    PATH_TO_AR = File.expand_path("../../activerecord/lib", __dir__)
    raise LoadError, "#{PATH_TO_AR} doesn't exist" unless File.directory?(PATH_TO_AR)
    $LOAD_PATH.unshift PATH_TO_AR
    require "active_record"
  rescue LoadError => e
    $stderr.print "Failed to load Active Record. Skipping Active Record assertion tests: #{e}"
    ActiveRecordTestConnector.able_to_connect = false
  end
end
$stderr.flush

# Define the rest of the connector
class ActiveRecordTestConnector
  class << self
    def setup
      unless connected || !able_to_connect
        setup_connection
        load_schema
        require_fixture_models
        self.connected = true
      end
    rescue Exception => e  # errors from ActiveRecord setup
      $stderr.puts "\nSkipping ActiveRecord assertion tests: #{e}"
      # $stderr.puts "  #{e.backtrace.join("\n  ")}\n"
      self.able_to_connect = false
    end

    def reconnect
      return unless able_to_connect
      ActiveRecord::Base.connection.reconnect!
      load_schema
    end

    private
      def setup_connection
        if Object.const_defined?(:ActiveRecord)
          defaults = { database: ":memory:" }
          adapter = defined?(JRUBY_VERSION) ? "jdbcsqlite3" : "sqlite3"
          options = defaults.merge adapter: adapter, timeout: 500
          ActiveRecord::Base.establish_connection(options)
          ActiveRecord::Base.configurations = { "sqlite3_ar_integration" => options }
          ActiveRecord::Base.connection

          Object.send(:const_set, :QUOTED_TYPE, ActiveRecord::Base.connection.quote_column_name("type")) unless Object.const_defined?(:QUOTED_TYPE)
        else
          raise "Can't setup connection since ActiveRecord isn't loaded."
        end
      end

      # Load actionpack sqlite3 tables
      def load_schema
        File.read(File.expand_path("fixtures/db_definitions/sqlite.sql", __dir__)).split(";").each do |sql|
          ActiveRecord::Base.connection.execute(sql) unless sql.blank?
        end
      end

      def require_fixture_models
        Dir.glob(File.expand_path("fixtures/*.rb", __dir__)).each { |f| require f }
      end
  end
end

class ActiveRecordTestCase < ActionController::TestCase
  include ActiveRecord::TestFixtures

  def self.tests(controller)
    super
    if defined? controller::ROUTES
      include Module.new {
        define_method(:setup) do
          super()
          @routes = controller::ROUTES
        end
      }
    end
  end

  # Set our fixture path
  if ActiveRecordTestConnector.able_to_connect
    self.fixture_path = [FIXTURE_LOAD_PATH]
    self.use_transactional_tests = false
  end

  def self.fixtures(*args)
    super if ActiveRecordTestConnector.connected
  end

  def run(*args)
    super if ActiveRecordTestConnector.connected
  end
end

ActiveRecordTestConnector.setup

ActiveSupport::Testing::Parallelization.after_fork_hook do
  ActiveRecordTestConnector.reconnect
end
