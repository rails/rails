require "cases/helper"

class ConnectionSpecificationResolverWithDATABASEURLTest < ActiveRecord::TestCase
  def setup
    @previous_database_url = ENV.delete("DATABASE_URL")
  end

  teardown do
    ENV["DATABASE_URL"] = @previous_database_url
  end

  def resolve_spec(spec, config)
    config = ActiveRecord::ConnectionAdapters::ConnectionSpecification::ConnectionConfigurations.new(config)
    config.root_level = spec.to_s
    ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(config).resolve(spec)
  end

  def test_resolver_with_database_uri_and_current_env_symbol_key
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
    actual   = resolve_spec(:default_env, config)
    expected = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost", "name" => "default_env" }
    assert_equal expected, actual
  end

  def test_resolver_with_database_uri_and_supplied_url
    ENV["DATABASE_URL"] = "not-postgres://not-localhost/not_foo"
    config   = { "production" => {  "adapter" => "also_not_postgres", "database" => "also_not_foo" } }
    actual   = resolve_spec("postgres://localhost/foo", config)
    expected = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost" }
    assert_equal expected, actual
  end

  def test_jdbc_url
    config   = { "production" => { "url" => "jdbc:postgres://localhost/foo" } }
    actual   = resolve_spec(:production, config)
    assert_equal config["production"].merge("name" => "production"), actual
  end

  def test_environment_does_not_exist_in_config_url_does_exist
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    config      = { "not_default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
    actual      = resolve_spec(:primary, config)
    expect_prod = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost", "name" => "primary" }
    assert_equal expect_prod, actual
  end

  def test_url_with_hyphenated_scheme
    ENV["DATABASE_URL"] = "ibm-db://localhost/foo"
    config   = { "primary" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
    actual   = resolve_spec(:primary, config)
    expected = { "adapter" => "ibm_db", "database" => "foo", "host" => "localhost", "name" => "primary" }
    assert_equal expected, actual
  end

  def test_string_connection
    config   = { "default_env" => "postgres://localhost/foo" }
    actual   = resolve_spec(:default_env, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "name"     => "default_env"
               }
    assert_equal expected, actual
  end

  def test_url_sub_key
    config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
    actual   = resolve_spec(:default_env, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "name"     => "default_env"
               }
    assert_equal expected, actual
  end

  def test_hash
    config = { "production" => { "adapter" => "postgres", "database" => "foo" } }
    actual = resolve_spec(:production, config)
    assert_equal config["production"].merge("name" => "production"), actual
  end

  def test_blank_with_database_url
    ENV["DATABASE_URL"] = "postgres://localhost/foo"

    config   = {}
    actual   = resolve_spec(:development, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "name"     => "development"
               }
    assert_equal expected, actual
  end

  def test_database_url_with_ipv6_host_and_port
    ENV["DATABASE_URL"] = "postgres://[::1]:5454/foo"

    config   = {}
    actual   = resolve_spec(:primary, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "::1",
                 "port"     => 5454,
                 "name"     => "primary"
               }
    assert_equal expected, actual
  end

  def test_url_sub_key_with_database_url
    ENV["DATABASE_URL"] = "NOT-POSTGRES://localhost/NOT_FOO"

    config   = { "primary" => { "url" => "postgres://localhost/foo" } }
    actual   = resolve_spec(:primary, config)
    expected = { "adapter" => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "name"     => "primary"
               }
    assert_equal expected, actual
  end

  def test_merge_no_conflicts_with_database_url
    ENV["DATABASE_URL"] = "postgres://localhost/foo"

    config   = { "primary" => { "pool" => "5" } }
    actual   = resolve_spec(:primary, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "pool"     => "5",
                 "name"     => "primary"
               }
    assert_equal expected, actual
  end

  def test_merge_conflicts_with_database_url
    ENV["DATABASE_URL"] = "postgres://localhost/foo"

    config   = { "primary" => { "adapter" => "NOT-POSTGRES", "database" => "NOT-FOO", "pool" => "5" } }
    actual   = resolve_spec(:primary, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "pool"     => "5",
                 "name"     => "primary"
               }
    assert_equal expected, actual
  end
end
