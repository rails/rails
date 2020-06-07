# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DevTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "`bin/rails dev:cache` creates both caching and restart file when restart file doesn't exist and dev caching is currently off" do
    Dir.chdir(app_path) do
      assert_not File.exist?("tmp/caching-dev.txt")
      assert_not File.exist?("tmp/restart.txt")

      assert_equal <<~OUTPUT, run_dev_cache_command
        Development mode is now being cached.
      OUTPUT

      assert File.exist?("tmp/caching-dev.txt")
      assert File.exist?("tmp/restart.txt")
    end
  end

  test "`bin/rails dev:cache` creates caching file and touches restart file when dev caching is currently off" do
    Dir.chdir(app_path) do
      app_file("tmp/restart.txt", "")

      assert_not File.exist?("tmp/caching-dev.txt")
      assert File.exist?("tmp/restart.txt")
      restart_file_time_before = File.mtime("tmp/restart.txt")

      assert_equal <<~OUTPUT, run_dev_cache_command
        Development mode is now being cached.
      OUTPUT

      assert File.exist?("tmp/caching-dev.txt")
      restart_file_time_after = File.mtime("tmp/restart.txt")
      assert_operator restart_file_time_before, :<, restart_file_time_after
    end
  end

  test "`bin/rails dev:cache` removes caching file and touches restart file when dev caching is currently on" do
    Dir.chdir(app_path) do
      app_file("tmp/caching-dev.txt", "")
      app_file("tmp/restart.txt", "")

      assert File.exist?("tmp/caching-dev.txt")
      assert File.exist?("tmp/restart.txt")
      restart_file_time_before = File.mtime("tmp/restart.txt")

      assert_equal <<~OUTPUT, run_dev_cache_command
        Development mode is no longer being cached.
      OUTPUT

      assert_not File.exist?("tmp/caching-dev.txt")
      restart_file_time_after = File.mtime("tmp/restart.txt")
      assert_operator restart_file_time_before, :<, restart_file_time_after
    end
  end

  private
    def run_dev_cache_command
      rails "dev:cache"
    end
end
