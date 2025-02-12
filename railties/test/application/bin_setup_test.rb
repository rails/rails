# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class BinSetupTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    def test_bin_setup
      Dir.chdir(app_path) do
        rails "generate", "model", "article"

        list_tables = lambda { rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip }
        File.write("log/test.log", "zomg!")

        assert_equal "[]", list_tables.call
        assert_equal 5, File.size("log/test.log")
        assert_not File.exist?("tmp/restart.txt")

        `bin/setup --skip-server 2>&1`
        assert_equal 0, File.size("log/test.log")
        assert_equal '["ar_internal_metadata", "articles", "schema_migrations"]', list_tables.call
      end
    end

    def test_bin_setup_output
      Dir.chdir(app_path) do
        # SQLite3 seems to auto-create the database on first checkout.
        rails "db:system:change", "--to=postgresql"
        rails "db:drop", allow_failure: true

        app_file "db/schema.rb", ""

        output = `bin/setup --skip-server 2>&1`

        # Ignore line that's only output by Bundler < 1.14
        output.sub!(/^Resolving dependencies\.\.\.\n/, "")
        # Suppress Bundler platform warnings from output
        output.gsub!(/^The dependency .* will be unused .*\.\n/, "")
        # Ignores dynamic data by yarn
        output.sub!(/^yarn install v.*?$/, "yarn install")
        output.sub!(/^\[.*?\] Resolving packages\.\.\.$/, "[1/4] Resolving packages...")
        output.sub!(/^Done in \d+\.\d+s\.\n/, "Done in 0.00s.\n")
        # Ignore warnings such as `Psych.safe_load is deprecated`
        output.gsub!(/^.*warning:\s.*\n/, "")
        output.gsub!(/^A new release of RubyGems is available.*\n.*\n/, "")

        assert_equal(<<~OUTPUT, output)
          == Installing dependencies ==
          The Gemfile's dependencies are satisfied

          == Preparing database ==
          Created database 'app_development'
          Created database 'app_test'

          == Removing old logs and tempfiles ==
        OUTPUT
      end
    end
  end
end
