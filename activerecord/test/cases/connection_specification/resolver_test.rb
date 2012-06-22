require "cases/helper"

module ActiveRecord
  class Base
    class ConnectionSpecification
      class ResolverTest < ActiveRecord::TestCase
        def resolve(spec)
          Resolver.new(spec, {}).spec.config
        end

        def with_database_url(new_url)
          old_url, ENV['DATABASE_URL'] = ENV['DATABASE_URL'], new_url
          yield
        ensure
          old_url ? ENV['DATABASE_URL'] = old_url : ENV.delete('DATABASE_URL')
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

        def test_url_no_database_yml
          with_database_url 'sqlite3://localhost/db/production.sqlite3' do
            spec = Resolver.new(ENV["DATABASE_URL"],{}).spec.config
            assert_equal({
              :adapter  => "sqlite3",
              :database => "db/production.sqlite3",
              :host     => "localhost" }, spec)
            spec = Resolver.new("production",{}).spec.config
            assert_equal({
              :adapter  => "sqlite3",
              :database => "db/production.sqlite3",
              :host     => "localhost" }, spec)
          end
        end
      end
    end
  end
end
