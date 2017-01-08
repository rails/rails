require "cases/helper"

class ConnectionSpecificationResolverTest < ActiveRecord::TestCase
  def resolve(config, base_config = {})
    ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(base_config).resolve(config)
  end

  def spec(config, base_config = {})
    ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(base_config).spec(config)
  end

  def test_url_invalid_adapter
    error = assert_raises(LoadError) do
      spec "ridiculous://foo?encoding=utf8"
    end

    assert_match "Could not load 'active_record/connection_adapters/ridiculous_adapter'", error.message
  end

  # The abstract adapter is used simply to bypass the bit of code that
  # checks that the adapter file can be required in.

  def test_url_from_environment
    spec = resolve :production, "production" => "abstract://foo?encoding=utf8"
    assert_equal({
                   "adapter"  =>  "abstract",
                   "host"     =>  "foo",
                   "encoding" => "utf8",
                   "name"     => "production" }, spec)
  end

  def test_url_sub_key
    spec = resolve :production, "production" => { "url" => "abstract://foo?encoding=utf8" }
    assert_equal({
                   "adapter"  => "abstract",
                   "host"     => "foo",
                   "encoding" => "utf8",
                   "name"     => "production" }, spec)
  end

  def test_url_sub_key_merges_correctly
    hash = { "url" => "abstract://foo?encoding=utf8&", "adapter" => "sqlite3", "host" => "bar", "pool" => "3" }
    spec = resolve :production, "production" => hash
    assert_equal({
                   "adapter"  => "abstract",
                   "host"     => "foo",
                   "encoding" => "utf8",
                   "pool"     => "3",
                   "name"     => "production" }, spec)
  end

  def test_url_host_no_db
    spec = resolve "abstract://foo?encoding=utf8"
    assert_equal({
                   "adapter"  => "abstract",
                   "host"     => "foo",
                   "encoding" => "utf8" }, spec)
  end

  def test_url_missing_scheme
    spec = resolve "foo"
    assert_equal({
                   "database" => "foo" }, spec)
  end

  def test_url_host_db
    spec = resolve "abstract://foo/bar?encoding=utf8"
    assert_equal({
                   "adapter"  => "abstract",
                   "database" => "bar",
                   "host"     => "foo",
                   "encoding" => "utf8" }, spec)
  end

  def test_url_port
    spec = resolve "abstract://foo:123?encoding=utf8"
    assert_equal({
                   "adapter"  => "abstract",
                   "port"     => 123,
                   "host"     => "foo",
                   "encoding" => "utf8" }, spec)
  end

  def test_encoded_password
    password = "am@z1ng_p@ssw0rd#!"
    encoded_password = URI.encode_www_form_component(password)
    spec = resolve "abstract://foo:#{encoded_password}@localhost/bar"
    assert_equal password, spec["password"]
  end

  def test_url_with_authority_for_sqlite3
    spec = resolve "sqlite3:///foo_test"
    assert_equal("/foo_test", spec["database"])
  end

  def test_url_absolute_path_for_sqlite3
    spec = resolve "sqlite3:/foo_test"
    assert_equal("/foo_test", spec["database"])
  end

  def test_url_relative_path_for_sqlite3
    spec = resolve "sqlite3:foo_test"
    assert_equal("foo_test", spec["database"])
  end

  def test_url_memory_db_for_sqlite3
    spec = resolve "sqlite3::memory:"
    assert_equal(":memory:", spec["database"])
  end

  def test_url_sub_key_for_sqlite3
    spec = resolve :production, "production" => { "url" => "sqlite3:foo?encoding=utf8" }
    assert_equal({
                   "adapter"  => "sqlite3",
                   "database" => "foo",
                   "encoding" => "utf8",
                   "name"     => "production" }, spec)
  end

  def test_spec_name_on_key_lookup
    spec = spec(:readonly, "readonly" => { "adapter" => "sqlite3" })
    assert_equal "readonly", spec.name
  end

  def test_spec_name_with_inline_config
    spec = spec("adapter" => "sqlite3")
    assert_equal "primary", spec.name, "should default to primary id"
  end
end

class ConnectionSpecificationResolverWithDEFAULTURLTest < ActiveRecord::TestCase
  def setup
    @previous_database_url = ENV.delete("DATABASE_URL")
  end

  teardown do
    ENV["DATABASE_URL"] = @previous_database_url
  end

  def resolve_spec(spec, config)
    ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(config).resolve(spec)
  end

  def test_resolver_with_database_uri_and_current_env_symbol_key
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
    actual   = resolve_spec(:primary, config)
    expected = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost", "name" => "primary" }
    assert_equal expected, actual
  end

  def test_resolver_with_database_uri_and_known_key
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    config   = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
    actual   = resolve_spec(:production, config)
    expected = { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost", "name" => "production" }
    assert_equal expected, actual
  end

  def test_resolver_with_database_uri_and_unknown_symbol_key
    ENV["DATABASE_URL"] = "postgres://localhost/foo"
    config = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
    assert_raises ActiveRecord::AdapterNotSpecified do
      resolve_spec(:production, config)
    end
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
    assert_equal config['production'].merge('name' => 'production'), actual
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
    assert_equal config['production'].merge('name' => 'production'), actual
  end

  def test_blank_with_database_url
    ENV["DATABASE_URL"] = "postgres://localhost/foo"

    config   = {}
    actual   = resolve_spec(:primary, config)
    expected = { "adapter"  => "postgresql",
                 "database" => "foo",
                 "host"     => "localhost",
                 "name"     => "primary"
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
