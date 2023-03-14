# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::TmpTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "tmp:clear clear cache, socket, screenshot, and storage files" do
    app_file "tmp/cache/cache_file", "cache"
    app_file "tmp/sockets/socket_file", "socket"
    app_file "tmp/screenshots/fail.png", "screenshot"
    app_file "tmp/storage/6h/np/6hnp81jvgt42pcfqtlpoy8qshfb0", "storage"

    rails "tmp:clear"

    assert_dir_cleared "tmp/cache"
    assert_dir_cleared "tmp/sockets"
    assert_dir_cleared "tmp/screenshots"
    assert_dir_cleared "tmp/storage", [".keep"]
  end

  test "tmp:create creates tmp folders" do
    FileUtils.remove_dir "#{app_path}/tmp"
    rails "tmp:create"
    assert_dir_created "tmp/cache"
    assert_dir_created "tmp/sockets"
    assert_dir_created "tmp/pids"
    assert_dir_created "tmp/cache/assets"
  end

  test "tmp:clear should not fail if folder missing" do
    FileUtils.remove_dir "#{app_path}/tmp"
    rails "tmp:clear"
  end

  test "tmp:cache:clear" do
    app_file "tmp/cache/cache_file", "cache"
    rails "tmp:cache:clear"
    assert_dir_cleared "tmp/cache"
  end

  test "tmp:pids:clear" do
    app_file "tmp/pids/pid_file", "pid"
    rails "tmp:pids:clear"
    assert_dir_cleared "tmp/pids", [".keep"]
  end

  test "tmp:screenshots:clear" do
    app_file "tmp/screenshots/screenshot_file", "screenshot"
    rails "tmp:screenshots:clear"
    assert_dir_cleared "tmp/screenshots"
  end

  test "tmp:sockets:clear" do
    app_file "tmp/sockets/socket_file", "socket"
    rails "tmp:sockets:clear"
    assert_dir_cleared "tmp/sockets"
  end

  test "tmp:storage:clear" do
    app_file "tmp/storage/storage_file", "storage"
    rails "tmp:storage:clear"
    assert_dir_cleared "tmp/storage", [".keep"]
  end

  def assert_dir_cleared(path, expected = [])
    dir_path = "#{app_path}/#{path}"
    assert Dir.exist?(dir_path), "Expected dir #{path.inspect} to exist, but does not"

    actual = Dir.entries(dir_path) - [".", ".."]
    assert_equal expected, actual, "#{expected} files expected in #{path.inspect}, but #{actual} were found"
  end

  def assert_dir_created(path)
    assert Dir.exist?("#{app_path}/#{path}")
  end
end
