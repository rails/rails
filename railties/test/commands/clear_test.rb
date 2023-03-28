# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::ClearTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  setup :build_app
  teardown :teardown_app

  test "`rails clear --logs` clears all environments log files by default" do
    app_file "config/environments/staging.rb", "# staging"

    app_file "log/staging.log", "staging"
    app_file "log/test.log", "test"
    app_file "log/dummy.log", "dummy"

    rails "clear", "--logs"

    assert_file_empty     "log/staging.log"
    assert_file_empty     "log/test.log"
    assert_file_not_empty "log/dummy.log"
  end

  test "`rails clear --logs all` clears all log files" do
    app_file "log/test.log", "test"
    app_file "log/dummy.log", "dummy"
    app_file "log/not_a_log", "not_a_log"

    rails "clear", "--logs", "all"

    assert_file_empty     "log/test.log"
    assert_file_empty     "log/dummy.log"
    assert_file_not_empty "log/not_a_log"
  end

  test "`rails clear --logs env1 env2` clears only logs for the specified environments" do
    app_file "config/environments/staging.rb", "# staging"

    app_file "log/production.log", "production"
    app_file "log/staging.log", "staging"
    app_file "log/test.log", "test"
    app_file "log/dummy.log", "dummy"

    rails "clear", "--logs", "test", "staging"

    assert_file_not_empty "log/production.log"
    assert_file_empty     "log/test.log"
    assert_file_empty     "log/staging.log"
    assert_file_not_empty "log/dummy.log"
  end

  private
    def assert_file_empty(path)
      assert File.empty? app_path(path)
    end

    def assert_file_not_empty(path)
      assert File.size? app_path(path)
    end
end
