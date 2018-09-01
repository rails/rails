# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeDevTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        add_to_env_config("development", "config.active_support.deprecation = :stderr")
      end

      def teardown
        teardown_app
      end

      test "dev:cache creates file and outputs message" do
        Dir.chdir(app_path) do
          stderr = capture(:stderr) do
            output = run_rake_dev_cache
            assert File.exist?("tmp/caching-dev.txt")
            assert_match(/Development mode is now being cached/, output)
          end
          assert_match(/DEPRECATION WARNING: Using `bin\/rake dev:cache` is deprecated and will be removed in Rails 6.1/, stderr)
        end
      end

      test "dev:cache deletes file and outputs message" do
        Dir.chdir(app_path) do
          stderr = capture(:stderr) do
            run_rake_dev_cache # Create caching file.
            output = run_rake_dev_cache # Delete caching file.
            assert_not File.exist?("tmp/caching-dev.txt")
            assert_match(/Development mode is no longer being cached/, output)
          end
          assert_match(/DEPRECATION WARNING: Using `bin\/rake dev:cache` is deprecated and will be removed in Rails 6.1/, stderr)
        end
      end

      test "dev:cache touches tmp/restart.txt" do
        Dir.chdir(app_path) do
          stderr = capture(:stderr) do
            run_rake_dev_cache
            assert File.exist?("tmp/restart.txt")

            prev_mtime = File.mtime("tmp/restart.txt")
            run_rake_dev_cache
            curr_mtime = File.mtime("tmp/restart.txt")
            assert_not_equal prev_mtime, curr_mtime
          end
          assert_match(/DEPRECATION WARNING: Using `bin\/rake dev:cache` is deprecated and will be removed in Rails 6.1/, stderr)
        end
      end

      private
        def run_rake_dev_cache
          `bin/rake dev:cache`
        end
    end
  end
end
