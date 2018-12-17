# frozen_string_literal: true

require "abstract_unit"
require "minitest/mock"
require "rails/command"
require "rails/commands/db/system/system_command"

class Rails::Db::SystemTest < ActiveSupport::TestCase
  test "to_s with single config" do
    config = {
      "test" => {
        "primary" => {
          "adapter" => "sqlite3"
        }
      }
    }

    app_db_config(config) do
      assert_equal "sqlite3", Rails::Db::System.new.to_s
    end
  end


  test "to_s with multiple configs" do
    config = {
      "test" => {
        "primary" => {
          "adapter" => "postgresql"
        },
        "secondary" => {
          "adapter" => "mysql2"
        }
      }
    }

    app_db_config(config) do
      assert_equal <<~OUTPUT.chomp, Rails::Db::System.new.to_s
        primary => postgresql
        secondary => mysql2
      OUTPUT
    end
  end

  test "environment via parameter" do
    system = Rails::Db::System.new("environment" => "production")
    assert_equal "production", system.environment
  end

  test "environment via current Rails.env" do
    assert_equal "test", Rails::Db::System.new.environment
  end

  test "environment via environment variables" do
    ENV["RAILS_ENV"] = nil
    ENV["RACK_ENV"] = nil

    Rails.stub(:respond_to?, false) do
      assert_equal "development", Rails::Db::System.new.environment

      ENV["RACK_ENV"] = "rack_env"
      assert_equal "rack_env", Rails::Db::System.new.environment

      ENV["RAILS_ENV"] = "rails_env"
      assert_equal "rails_env", Rails::Db::System.new.environment
    end
  ensure
    ENV["RAILS_ENV"] = "test"
    ENV["RACK_ENV"] = nil
  end

  test "command" do
    config = {
      "test" => {
        "adapter" => "mysql2"
      }
    }

    app_db_config(config) do
      output = capture(:stdout) do
        Rails::Command.invoke("db:system")
      end
      assert_equal "mysql2", output.chomp
    end
  end

  test "command with environment" do
    config = {
      "development" => {
        "adapter" => "sqlite3"
      },
      "test" => {
        "adapter" => "mysql2"
      },
      "production" => {
        "adapter" => "postgresql"
      }
    }

    app_db_config(config) do
      output = capture(:stdout) do
        Rails::Command.invoke("db:system", ["-e", "production"])
      end
      assert_equal "postgresql", output.chomp
    end
  end

  private

    def app_db_config(config)
      old_configurations = ActiveRecord::Base.configurations
      new_configurations = ActiveRecord::DatabaseConfigurations.new(config || {})
      ActiveRecord::Base.configurations = new_configurations
      yield
    ensure
      ActiveRecord::Base.configurations = old_configurations
    end
end
