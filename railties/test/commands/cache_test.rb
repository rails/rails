# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/tmp/cache_command"

class Rails::Command::CacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  setup :build_app
  teardown :teardown_app

  test "clears all files and directories" do
    Dir.chdir(app_path) do
      FileUtils.touch("tmp/cache/test.txt")
      FileUtils.mkdir_p("tmp/cache/foo/")

      rails "tmp:cache:clear"

      assert_equal false, File.exist?("tmp/cache/test.txt")
      assert_equal false, File.directory?("tmp/cache/foo/")
    end
  end
end
