# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec, config = {})
          Resolver.new(config).resolve(spec)
        end

        def spec(spec, config = {})
          Resolver.new(config).spec(spec)
        end

        def test_url_invalid_adapter
          error = assert_raises(LoadError) do
            spec "ridiculous://foo?encoding=utf8"
          end

          assert_match "Could not load the 'ridiculous' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", error.message
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
    end
  end
end
