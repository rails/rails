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

  test "should watch symlinked directories" do
    i = 0

    subdir = tmpfile("subdir")
    subdir_with_symlink = tmpfile("subdir_with_symlink")
    symlink = tmpfile("subdir_with_symlink/symlink")

    mkdir(subdir)
    mkdir(subdir_with_symlink)
    File.symlink(subdir, symlink)

    checker = new_checker([], subdir_with_symlink => :rb) { i += 1 }

    touch(tmpfile("subdir/foo.rb"))

    assert checker.execute_if_updated
    assert_equal 1, i
  end
end
