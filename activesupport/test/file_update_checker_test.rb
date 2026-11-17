# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "file_update_checker_shared_tests"

class FileUpdateCheckerTest < ActiveSupport::TestCase
  include FileUpdateCheckerSharedTests

  def new_checker(files = [], dirs = {}, &block)
    ActiveSupport::FileUpdateChecker.new(files, dirs, &block)
  end

  def touch(files)
    sleep 0.1 # let's wait a bit to ensure there's a new mtime
    super
  end

  test "should not reload files that appear in the future due to time travel" do
    i = 0

    checker = new_checker(tmpfiles) { i += 1 }
    touch(tmpfiles)

    assert checker.execute_if_updated
    assert_equal 1, i

    original_last_update_at = checker.instance_variable_get(:@last_update_at)
    assert original_last_update_at > Time.utc(2020, 1, 1), "Expected @last_update_at to be recent"

    # Travel to the past, making current files appear to be in the future
    travel_to Time.utc(2020, 1, 1) do
      # With the old implementation with Time.new, this would corrupt @last_update_at to Time.at(0)
      # because max_mtime would use stubbed Time.now and skip all files as "future" in max_mtime, returning nil.
      # With Process.clock_gettime, the state should be preserved during time travel.
      checker.execute
    end

    assert_not checker.updated?, "Should not reload after time travel when state is preserved"

    final_state = checker.instance_variable_get(:@last_update_at)
    assert_not_equal Time.at(0), final_state,
      "State should not be corrupted after time travel"

    touch(tmpfiles)
    assert checker.execute_if_updated
    assert_equal 3, i
  end
end
