require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, {}).spec.config
        end

        def test_url_host_no_db
          skip "only if mysql is available" unless current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
          spec = resolve 'mysql://foo?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_host_db
          skip "only if mysql is available" unless current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
          spec = resolve 'mysql://foo/bar?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "bar",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_port
          skip "only if mysql is available" unless current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
          spec = resolve 'mysql://foo:123?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :port     => 123,
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_encoded_password
          skip "only if mysql is available" unless current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
          password = 'am@z1ng_p@ssw0rd#!'
          encoded_password = URI.encode_www_form_component(password)
          spec = resolve "mysql://foo:#{encoded_password}@localhost/bar"
          assert_equal password, spec[:password]
        end
      end
    end
  end
end
