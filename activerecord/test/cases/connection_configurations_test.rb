# frozen_string_literal: true

require "cases/helper"

class ConnectionConfigurationsTest < ActiveRecord::TestCase
  def test_shards_connection_configurations
    config_hash = {
      "ApplicationRecord" => {
        "shards" => {
          "default" => {
            "writing" => "arunit",
            "reading" => "arunit"
          }
        }
      }
    }

    connection_configurations = ActiveRecord::ConnectionConfigurations.new(config_hash)

    assert_equal 1, connection_configurations.count
    connection_configuration = connection_configurations.configs_for(class_name: "ApplicationRecord")
    assert_equal 1, connection_configuration.connection_config[:shards].count
    assert_equal({ default: { writing: :arunit, reading: :arunit } }, connection_configuration.connection_config[:shards])
  end

  def test_database_connection_configurations
    config_hash = {
      "ApplicationRecord" => {
        "database" => {
          "writing" => "arunit",
          "reading" => "arunit"
        }
      }
    }

    connection_configurations = ActiveRecord::ConnectionConfigurations.new(config_hash)

    assert_equal 1, connection_configurations.count
    connection_configuration = connection_configurations.configs_for(class_name: "ApplicationRecord")
    assert_equal 2, connection_configuration.connection_config[:database].count
    assert_equal({ writing: :arunit, reading: :arunit }, connection_configuration.connection_config[:database])
  end

  def test_shards_and_database_cant_both_be_set
    config_hash = {
      "ApplicationRecord" => {
        "shards" => {
          "default" => {
            "writing" => "arunit",
            "reading" => "arunit"
          }
        },
        "database" => {
          "writing" => "arunit",
          "reading" => "arunit"
        }
      }
    }

    error = assert_raises ArgumentError do
      ActiveRecord::ConnectionConfigurations.new(config_hash)
    end

    assert_equal "Connection configurations can only accept a `database` or `shards` argument, but not both arguments.", error.message
  end
end
