require 'cases/helper'

if ActiveRecord::Base.connection.supports_explain?
  class ExplainSubscriberTest < ActiveRecord::TestCase
    SUBSCRIBER = ActiveRecord::ExplainSubscriber.new

    def test_collects_nothing_if_available_queries_for_explain_is_nil
      with_queries(nil) do
        SUBSCRIBER.finish(nil, nil, {})
        assert_nil Thread.current[:available_queries_for_explain]
      end
    end

    def test_collects_nothing_if_the_payload_has_an_exception
      with_queries([]) do |queries|
        SUBSCRIBER.finish(nil, nil, :exception => Exception.new)
        assert queries.empty?
      end
    end

    def test_collects_nothing_for_ignored_payloads
      with_queries([]) do |queries|
        ActiveRecord::ExplainSubscriber::IGNORED_PAYLOADS.each do |ip|
          SUBSCRIBER.finish(nil, nil, :name => ip)
        end
        assert queries.empty?
      end
    end

    def test_collects_pairs_of_queries_and_binds
      sql   = 'select 1 from users'
      binds = [1, 2]
      with_queries([]) do |queries|
        SUBSCRIBER.finish(nil, nil, :name => 'SQL', :sql => sql, :binds => binds)
        assert_equal 1, queries.size
        assert_equal sql, queries[0][0]
        assert_equal binds, queries[0][1]
      end
    end

    def test_collects_nothing_if_unexplained_sqls
      with_queries([]) do |queries|
        SUBSCRIBER.finish(nil, nil, :name => 'SQL', :sql => 'SHOW max_identifier_length')
        assert queries.empty?
      end
    end

    def with_queries(queries)
      Thread.current[:available_queries_for_explain] = queries
      yield queries
    ensure
      Thread.current[:available_queries_for_explain] = nil
    end
  end
end
