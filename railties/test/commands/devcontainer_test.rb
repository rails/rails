# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DevcontainerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  teardown { teardown_app }

  test "generates devcontainer for default app" do
    build_app

    output = rails "devcontainer"

    assert_match "app_name: app_template", output
    assert_match "database: sqlite3", output
    assert_match "active_storage: true", output
    assert_match "redis: true", output
    assert_match "system_test: true", output
    assert_match "node: false", output
  end
end
