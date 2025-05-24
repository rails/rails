# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "file_update_checker_shared_tests"
require "active_support/core_ext/integer/time"

class FileUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerSharedTests
  include ActiveSupport::Testing::TimeHelpers

  def new_checker(files = [], dirs = {}, &block)
    ActiveSupport::FileUpdateChecker.new(files, dirs, &block)
  end

  def touch(files)
    sleep 0.1 # let's wait a bit to ensure there's a new mtime
    super
  end

  def test_does_not_trigger_update_when_traveling_in_time
    Dir.mktmpdir do |tmpdir|
      file_path = File.join(tmpdir, "watched.txt")
      FileUtils.touch(file_path)

      checker = nil

      travel_to 1.hour.ago do
        checker = ActiveSupport::FileUpdateChecker.new([file_path]) { nil }
        assert_not checker.updated?, "should be false immediately after initialization"
      end

      travel_to 1.hour.since do
        assert_not checker.updated?, "should be false when file has not changed despite time travel"
      end
    end
  end
end
