# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DbSystemChangeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup { build_app }

  teardown { teardown_app }

  test "change to existing database" do
    change_database(to: "sqlite3")

    output = change_database(to: "sqlite3")

    assert_match "identical  config/database.yml", output
    assert_match "gsub  Gemfile", output
  end

  test "change to invalid database" do
    output = change_database(to: "invalid-db")

    assert_match <<~MSG.squish, output
      Invalid value for --to option.
      Supported preconfigurations are:
      mysql, trilogy, postgresql, sqlite3, mariadb-mysql, mariadb-trilogy.
    MSG
  end

  test "change to postgresql" do
    output = change_database(to: "postgresql")

    assert_match "force  config/database.yml", output
    assert_match "gsub  Gemfile", output
  end

  test "change to mysql" do
    output = change_database(to: "mysql")

    assert_match "force  config/database.yml", output
    assert_match "gsub  Gemfile", output
  end

  test "change to sqlite3" do
    change_database(to: "postgresql")
    output = change_database(to: "sqlite3")

    assert_match "force  config/database.yml", output
    assert_match "gsub  Gemfile", output
  end

  test "change can be forced" do
    output = `cd #{app_path}; bin/rails db:system:change --to=postgresql --force`

    assert_match "force  config/database.yml", output
    assert_match "gsub  Gemfile", output
  end

  test "change works with no Dockerfile" do
    remove_file("Dockerfile")

    output = change_database(to: "sqlite3")

    assert_match "gsub  Gemfile", output
  end

  private
    def change_database(to:, **options)
      args = ["--to", to]
      rails "db:system:change", args, **options
    end
end
