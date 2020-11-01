# frozen_string_literal: true

require "isolation/abstract_unit"
require "chdir_helpers"

module ApplicationTests
  class BinSetupTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, ChdirHelpers

    setup :build_app
    teardown :teardown_app

    def test_bin_setup
      Dir.chdir(app_path) do
        rails "generate", "model", "article"

        list_tables = lambda { rails("runner", "p ActiveRecord::Base.connection.tables").strip }
        File.write("log/test.log", "zomg!")

        assert_equal "[]", list_tables.call
        assert_equal 5, File.size("log/test.log")
        assert_not File.exist?("tmp/restart.txt")

        `bin/setup 2>&1`
        assert_equal 0, File.size("log/test.log")
        assert_equal '["schema_migrations", "ar_internal_metadata", "articles"]', list_tables.call
        assert File.exist?("tmp/restart.txt")
      end
    end

    def test_bin_setup_output
      chdir(app_path) do
        # SQLite3 seems to auto-create the database on first checkout.
        rails "db:system:change", "--to=postgresql"
        rails "db:drop"

        app_file "db/schema.rb", ""

        output = `bin/setup 2>&1`

        # Ignore line that's only output by Bundler < 1.14
        output.sub!(/^Resolving dependencies\.\.\.\n/, "")
        # Suppress Bundler platform warnings from output
        output.gsub!(/^The dependency .* will be unused .*\.\n/, "")
        # Ignore warnings such as `Psych.safe_load is deprecated`
        output.gsub!(/^warning:\s.*\n/, "")

        assert_equal(<<~OUTPUT, output)
          == Installing dependencies ==
          The Gemfile's dependencies are satisfied

          == Preparing database ==
          Created database 'app_development'
          Created database 'app_test'

          == Removing old logs and tempfiles ==

          == Restarting application server ==
        OUTPUT
      end
    end
  end
end
