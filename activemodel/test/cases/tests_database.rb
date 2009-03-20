require 'logger'

$:.unshift(File.dirname(__FILE__) + '/../../../activerecord/lib')
require 'active_record'
require 'active_record/fixtures'

module ActiveModel
  module TestsDatabase
    def self.included(base)
      ActiveRecord::Base.logger = Logger.new("debug.log")
      ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

      base.send :include, ActiveRecord::TestFixtures
      base.setup :setup_database
    end

    def setup_database
      unless $schema_file_loaded
        begin
          # TODO : May the better way be with you
          original, $stdout = $stdout, StringIO.new
          load(SCHEMA_FILE)
        ensure
          $stdout = original
        end

        $schema_file_loaded = true
      end
    end
  end
end
