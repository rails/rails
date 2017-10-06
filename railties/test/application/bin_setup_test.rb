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
        output.sub!(/^Resolving dependencies\.\.\.\n/, "")

        assert_equal(<<-OUTPUT, output)
== Installing dependencies ==
The Gemfile's dependencies are satisfied

== Preparing database ==
Created database 'db/development.sqlite3'
Created database 'db/test.sqlite3'

== Removing old logs and tempfiles ==

== Restarting application server ==
        OUTPUT
      end
    end
  end
end
