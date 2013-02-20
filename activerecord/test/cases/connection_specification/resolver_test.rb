require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, {}).spec.config
        end

        def test_url_invalid_adapter
          assert_raises(LoadError) do
            resolve 'ridiculous://foo?encoding=utf8'
          end
        end

        # The abstract adapter is used simply to bypass the bit of code that
        # checks that the adapter file can be required in.

        def test_url_host_no_db
          spec = resolve 'abstract://foo?encoding=utf8'
          assert_equal({
            adapter:  "abstract",
            host:     "foo",
            encoding: "utf8" }, spec)
        end

        def test_url_host_db
          spec = resolve 'abstract://foo/bar?encoding=utf8'
          assert_equal({
            adapter:  "abstract",
            database: "bar",
            host:     "foo",
            encoding: "utf8" }, spec)
        end

        def test_url_port
          spec = resolve 'abstract://foo:123?encoding=utf8'
          assert_equal({
            adapter:  "abstract",
            port:     123,
            host:     "foo",
            encoding: "utf8" }, spec)
        end

        def test_url_query_numeric
          spec = resolve 'abstract://foo:123?encoding=utf8&int=500&float=10.9'
          assert_equal({
            adapter:  "abstract",
            port:     123,
            int:      500,
            float:    10.9,
            host:     "foo",
            encoding: "utf8" }, spec)
        end

        def test_url_query_boolean
          spec = resolve 'abstract://foo:123?true=true&false=false'
          assert_equal({
            adapter: "abstract",
            port:    123,
            true:    true,
            false:   false,
            host:    "foo" }, spec)
        end

        def test_encoded_password
          password = 'am@z1ng_p@ssw0rd#!'
          encoded_password = URI.encode_www_form_component(password)
          spec = resolve "abstract://foo:#{encoded_password}@localhost/bar"
          assert_equal password, spec[:password]
        end

        def test_descriptive_error_message_when_adapter_is_missing
          error = assert_raise(LoadError) do
            resolve(adapter: 'non-existing')
          end

          assert_match "Could not load 'active_record/connection_adapters/non-existing_adapter'", error.message
        end
      end
    end
  end
end
