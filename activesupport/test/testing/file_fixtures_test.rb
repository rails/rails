# frozen_string_literal: true

require "abstract_unit"

require "pathname"

class FileFixturesTest < ActiveSupport::TestCase
  self.file_fixture_path = File.expand_path("../file_fixtures", __dir__)

  test "#file_fixture returns Pathname to file fixture" do
    path = file_fixture("sample.txt")
    assert_kind_of Pathname, path
    assert_match %r{.*/test/file_fixtures/sample\.txt$}, path.to_s
  end

  test "raises an exception when the fixture file does not exist" do
    e = assert_raises(ArgumentError) do
      file_fixture("nope")
    end
    assert_match(/^the directory '[^']+test\/file_fixtures' does not contain a file named 'nope'$/, e.message)
  end
end

class FileFixturesPathnameDirectoryTest < ActiveSupport::TestCase
  self.file_fixture_path = Pathname.new(File.expand_path("../file_fixtures", __dir__))

  test "#file_fixture_path returns Pathname to file fixture" do
    path = file_fixture("sample.txt")
    assert_kind_of Pathname, path
    assert_match %r{.*/test/file_fixtures/sample\.txt$}, path.to_s
  end
end
