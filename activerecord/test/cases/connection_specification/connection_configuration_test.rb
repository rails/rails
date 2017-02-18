require "cases/helper"

class ConnectionConfigurationTest < ActiveRecord::TestCase

  def setup
    @previous_database_url = ENV.delete("DATABASE_URL")
  end

  teardown do
    ENV["DATABASE_URL"] = @previous_database_url
  end

  def connection_config(hash)
    ActiveRecord::ConnectionAdapters::ConnectionSpecification::ConnectionConfigurations.new(hash)
  end

  def test_get_value_with_two_level
    hash = { "production" => { "adapter" => "postgres", "database" => "foo" } }
    config = connection_config(hash)
    assert_equal "foo", config["production"]["database"]
  end

  def test_get_value_with_root_and_two_level
    hash = { "production" => { "adapter" => "postgres", "database" => "foo" } }
    config = connection_config(hash)
    config.root_level = "production"

    assert_equal "foo", config["production"]["database"]
    assert_nil config["development"]
  end

  def test_get_root_value_that_does_not_match_the_root_set
    hash = { "production" => { "adapter" => "postgres", "database" => "foo" } }
    config = connection_config(hash)
    config.root_level = "development"

    assert_equal "foo", config["production"]["database"]
  end

  def test_get_value_with_three_levels
    hash = { "production" => {"readonly" =>
             { "adapter" => "postgres", "database" => "foo" } } }
    config = connection_config(hash)
    config.root_level = "production"

    assert_equal "foo", config["readonly"]["database"]
  end

  def test_get_value_with_three_levels_in_another_root
    hash = {
      "production" => {
        "readonly" => { "adapter" => "postgres", "database" => "foo" }
      },
      "test" => {
        "readonly" => { "adapter" => "postgres", "database" => "foo_test" }
      }
    }
    config = connection_config(hash)
    config.root_level = "development"
    assert_nil config["readonly"]

    config.root_level = "test"
    assert_equal "foo_test", config["readonly"]["database"]

    config.root_level = "production"
    assert_equal "foo", config["readonly"]["database"]
  end

  def test_databaseurl_with_empty_config_should_set_under_root
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
#    hash = {
#      "development" => { "adapter" => "postgres", "database" => "foo_dev" },
#      "test" => { "adapter" => "postgres", "database" => "foo_test" }
#    }
    config = connection_config({})
    config.root_level = "development"

    assert_equal "foo", config["development"]["database"]
  end

  def test_databaseurl_should_set_under_root
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    hash = {
      "development" => { "adapter" => "postgres", "database" => "foo_dev" },
      "test" => { "adapter" => "postgres", "database" => "foo_test" }
    }
    config = connection_config(hash)
    config.root_level = "development"

    assert_equal "foo", config["development"]["database"]
    assert_equal "foo_test", config["test"]["database"]
  end
end
