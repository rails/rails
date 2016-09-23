require "isolation/abstract_unit"

module ApplicationTests
  class BinSetupTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app

      create_gemfile
      update_boot_file_to_use_bundler
      @old_gemfile_env = ENV["BUNDLE_GEMFILE"]
      ENV["BUNDLE_GEMFILE"] = app_path + "/Gemfile"
    end

    def teardown
      teardown_app

      ENV["BUNDLE_GEMFILE"] = @old_gemfile_env
    end

    def test_bin_setup
      Dir.chdir(app_path) do
        app_file "db/schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20140423102712) do
            create_table(:articles) {}
          end
        RUBY

        list_tables = lambda { `bin/rails runner 'p ActiveRecord::Base.connection.tables'`.strip }
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

    private
      def create_gemfile
        app_file("Gemfile", "source 'https://rubygems.org'")
        app_file("Gemfile", "gem 'rails', path: '#{RAILS_FRAMEWORK_ROOT}'", "a")
        app_file("Gemfile", "gem 'sqlite3'", "a")
      end

      def update_boot_file_to_use_bundler
        app_file("config/boot.rb", "require 'bundler/setup'")
      end
  end
end
