# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DevcontainerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  teardown { teardown_app }

  test "generates devcontainer for default app with solid gems" do
    build_app

    require "solid_cable"
    require "solid_queue"

    output = rails "devcontainer"

    assert_match "app_name: app_template", output
    assert_match "database: sqlite3", output
    assert_match "active_storage: true", output
    assert_match "redis: false", output
    assert_match "system_test: true", output
    assert_match "node: false", output
    assert_match "kamal: false", output
  end

  test "generates dev container for without solid gems" do
    build_app

    output = rails "devcontainer"

    assert_match "redis: true", output
  end

  test "generates dev container for using mysql2 app" do
    build_app

    Dir.chdir(app_path) do
      use_mysql2

      output = rails "devcontainer"

      assert_match "database: mysql", output

      assert_match "ghcr.io/rails/devcontainer/features/mysql-client", read_file(".devcontainer/devcontainer.json")
    end
  end

  private
    def read_file(relative)
      File.read(app_path(relative))
    end
end
