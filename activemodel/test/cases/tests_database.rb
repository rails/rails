require 'logger'

$:.unshift(File.dirname(__FILE__) + '/../../../activerecord/lib')
require 'active_record'
require 'active_record/fixtures'

module ActiveModel
  module TestsDatabase
    mattr_accessor :connected

    def self.included(base)
      unless self.connected
        setup_connection
        setup_schema
      end

      base.send :include, ActiveRecord::TestFixtures
    end

    def self.setup_schema
      original, $stdout = $stdout, StringIO.new
      load(SCHEMA_FILE)
    ensure
      $stdout = original
      self.connected = true
    end

    def self.setup_connection
      defaults = { :database => ':memory:' }
      begin
        adapter = defined?(JRUBY_VERSION) ? 'jdbcsqlite3' : 'sqlite3'
        options = defaults.merge :adapter => adapter, :timeout => 500
        ActiveRecord::Base.establish_connection(options)
      rescue Exception
        $stderr.puts 'SQLite 3 unavailable; trying SQLite 2.'
        options = defaults.merge :adapter => 'sqlite'
        ActiveRecord::Base.establish_connection(options)
      end
    end
  end
end
