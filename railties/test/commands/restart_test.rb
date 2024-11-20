# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::RestartTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  setup :build_app
  teardown :teardown_app

  test "rails restart touches tmp/restart.txt" do
    Dir.chdir(app_path) do
      rails "restart"
      assert File.exist?("tmp/restart.txt")

      prev_mtime = File.mtime("tmp/restart.txt")
      sleep(1)
      rails "restart"
      curr_mtime = File.mtime("tmp/restart.txt")
      assert_not_equal prev_mtime, curr_mtime
    end
  end

  test "rails restart should work even if tmp folder does not exist" do
    Dir.chdir(app_path) do
      FileUtils.remove_dir("tmp")
      rails "restart"
      assert File.exist?("tmp/restart.txt")
    end
  end
end
