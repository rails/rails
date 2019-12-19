# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class LogTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test "log:clear clear all environments log files by default" do
        Dir.chdir(app_path) do
          File.open("config/environments/staging.rb", "w")

          File.write("log/staging.log", "staging")
          File.write("log/test.log", "test")
          File.write("log/dummy.log", "dummy")

          rails "log:clear"

          assert_equal 0, File.size("log/test.log")
          assert_equal 0, File.size("log/staging.log")
          assert_equal 5, File.size("log/dummy.log")
        end
      end
    end
  end
end
