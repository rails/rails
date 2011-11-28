require "cases/helper"

module ActiveRecord
  class Base
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, ActiveRecord::Base, {}).spec.config
        end

        def test_url_host_no_db
          spec = resolve 'postgres://foo?encoding=utf8'
          assert_equal({
            :adapter  => "postgresql",
            :database => "",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_host_db
          spec = resolve 'postgres://foo/bar?encoding=utf8'
          assert_equal({
            :adapter  => "postgresql",
            :database => "bar",
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end

        def test_url_port
          spec = resolve 'postgres://foo:123?encoding=utf8'
          assert_equal({
            :adapter  => "postgresql",
            :database => "",
            :port     => 123,
            :host     => "foo",
            :encoding => "utf8" }, spec)
        end
      end
    end
  end
end
