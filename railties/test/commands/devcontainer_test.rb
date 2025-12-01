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

    assert_compose_file do |content|
      assert_equal "app_template", content["name"]

      expected_rails_app_config = {
        "build" => {
          "context" => "..",
          "dockerfile" => ".devcontainer/Dockerfile"
        },
        "volumes" => ["../../app:/workspaces/app:cached"],
        "command" => "sleep infinity",
        "depends_on" => ["selenium"]
      }

      assert_equal expected_rails_app_config, content["services"]["rails-app"]

      expected_selenium_config = {
        "image" => "selenium/standalone-chromium",
        "restart" => "unless-stopped",
      }

      assert_equal expected_selenium_config, content["services"]["selenium"]
    end
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

    def assert_compose_file
      content = read_file(".devcontainer/compose.yaml")
      yield YAML.load(content)
    end
end
