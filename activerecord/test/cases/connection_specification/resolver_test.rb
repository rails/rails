require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, {}).spec.config
        end

        def test_url_host_no_db
          spec = resolve 'mysql://foo?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_host_db
          spec = resolve 'mysql://foo/bar?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "bar",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_port
          spec = resolve 'mysql://foo:123?encoding=utf8'
          assert_equal({
            :adapter  => "mysql",
            :database => "",
            :port     => 123,
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end
      end
    end
  end
end
