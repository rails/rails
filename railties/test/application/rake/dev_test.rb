require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeDevTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test "dev:cache creates file and outputs message" do
        Dir.chdir(app_path) do
          output = `rails dev:cache`
          assert File.exist?("tmp/caching-dev.txt")
          assert_match(/Development mode is now being cached/, output)
        end
      end

      test "dev:cache deletes file and outputs message" do
        Dir.chdir(app_path) do
          `rails dev:cache` # Create caching file.
          output = `rails dev:cache` # Delete caching file.
          assert_not File.exist?("tmp/caching-dev.txt")
          assert_match(/Development mode is no longer being cached/, output)
        end
      end

      test "dev:cache removes server.pid also" do
        Dir.chdir(app_path) do
          FileUtils.mkdir_p("tmp/pids")
          FileUtils.touch("tmp/pids/server.pid")
          `rails dev:cache`
          assert_not File.exist?("tmp/pids/server.pid")
        end
      end
    end
  end
end
