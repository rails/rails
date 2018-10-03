# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class BinSetupTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_bin_setup
      Dir.chdir(app_path) do
        app_file "db/schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20140423102712) do
            create_table(:articles) {}
          end
        RUBY

        list_tables = lambda { rails("runner", "p ActiveRecord::Base.connection.tables").strip }
        File.write("log/test.log", "zomg!")

        assert_equal "[]", list_tables.call
        assert_equal 5, File.size("log/test.log")
        assert_not File.exist?("tmp/restart.txt")
        `bin/setup 2>&1`
        assert_equal 0, File.size("log/test.log")
        assert_equal '["articles", "schema_migrations", "ar_internal_metadata"]', list_tables.call
        assert File.exist?("tmp/restart.txt")
      end
    end

    def test_bin_setup_output
      Dir.chdir(app_path) do
        app_file "db/schema.rb", ""

        output = `bin/setup 2>&1`

        # Ignore line that's only output by Bundler < 1.14
        assert_match("== Installing dependencies ==", output)
        assert_match("The Gemfile's dependencies are satisfied", output)
        assert_match("== Preparing database ==", output)
        assert_match("Created database 'db/development.sqlite3'", output)
        assert_match("Created database 'db/test.sqlite3'", output)
        assert_match("== Preparing database ==", output)
        assert_match("== Removing old logs and tempfiles ==", output)
        assert_match("== Restarting application server ==", output)
      end
    end
  end
end
