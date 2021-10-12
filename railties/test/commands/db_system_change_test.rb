# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/db/system/change/change_command"

class Rails::Command::Db::System::ChangeCommandTest < ActiveSupport::TestCase
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
      mysql, postgresql, sqlite3, oracle,
      sqlserver, jdbcmysql, jdbcsqlite3,
      jdbcpostgresql, jdbc.
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

  private
    def change_database(to:, **options)
      args = ["--to", to]
      rails "db:system:change", args, **options
    end
end
