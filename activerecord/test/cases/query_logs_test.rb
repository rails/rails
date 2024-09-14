# frozen_string_literal: true

require "cases/helper"
require "models/dashboard"

class QueryLogsTest < ActiveRecord::TestCase
  fixtures :dashboards

  def setup
    # ActiveSupport::ExecutionContext context is automatically reset in Rails app via an executor hooks set in railtie
    # But not in Active Record's own test suite.
    ActiveSupport::ExecutionContext.clear

    # Enable the query tags logging
    @original_transformers = ActiveRecord.query_transformers
    @original_prepend = ActiveRecord::QueryLogs.prepend_comment
    @original_tags = ActiveRecord::QueryLogs.tags
    @original_taggings = ActiveRecord::QueryLogs.taggings
    ActiveRecord.query_transformers += [ActiveRecord::QueryLogs]
    ActiveRecord::QueryLogs.prepend_comment = false
    ActiveRecord::QueryLogs.cache_query_log_tags = false
    ActiveRecord::QueryLogs.cached_comment = nil
    ActiveRecord::QueryLogs.taggings = {
      application: -> { "active_record" }
    }
  end

  def teardown
    ActiveRecord.query_transformers = @original_transformers
    ActiveRecord::QueryLogs.prepend_comment = @original_prepend
    ActiveRecord::QueryLogs.tags = @original_tags
    ActiveRecord::QueryLogs.taggings = @original_taggings
    ActiveRecord::QueryLogs.prepend_comment = false
    ActiveRecord::QueryLogs.cache_query_log_tags = false
    ActiveRecord::QueryLogs.clear_cache
    ActiveRecord::QueryLogs.tags_formatter = :legacy

    # ActiveSupport::ExecutionContext context is automatically reset in Rails app via an executor hooks set in railtie
    # But not in Active Record's own test suite.
    ActiveSupport::ExecutionContext.clear
  end

  def test_escaping_good_comment
    assert_equal "app:foo", ActiveRecord::QueryLogs.send(:escape_sql_comment, "app:foo")
  end

  def test_escaping_good_comment_with_custom_separator
    ActiveRecord::QueryLogs.tags_formatter = :sqlcommenter

    assert_equal "app='foo'", ActiveRecord::QueryLogs.send(:escape_sql_comment, "app='foo'")
  end

  def test_escaping_bad_comments
    assert_equal "* /; DROP TABLE USERS;/ *", ActiveRecord::QueryLogs.send(:escape_sql_comment, "*/; DROP TABLE USERS;/*")
    assert_equal "** //; DROP TABLE USERS;/ *", ActiveRecord::QueryLogs.send(:escape_sql_comment, "**//; DROP TABLE USERS;/*")
    assert_equal "* * //; DROP TABLE USERS;// * *", ActiveRecord::QueryLogs.send(:escape_sql_comment, "* *//; DROP TABLE USERS;//* *")
  end

  def test_basic_commenting
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_queries_match(%r{select id from posts /\*application:active_record\*/$}) do
      ActiveRecord::Base.lease_connection.execute "select id from posts"
    end
  end

  def test_add_comments_to_beginning_of_query
    ActiveRecord::QueryLogs.tags = [ :application ]
    ActiveRecord::QueryLogs.prepend_comment = true

    assert_queries_match(%r{/\*application:active_record\*/ select id from posts$}) do
      ActiveRecord::Base.lease_connection.execute "select id from posts"
    end
  end

  def test_exists_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]
    assert_queries_match(%r{/\*application:active_record\*/}) do
      Dashboard.exists?
    end
  end

  def test_delete_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]
    record = Dashboard.first

    assert_queries_match(%r{/\*application:active_record\*/}) do
      record.destroy
    end
  end

  def test_update_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_queries_match(%r{/\*application:active_record\*/}) do
      dash = Dashboard.first
      dash.name = "New name"
      dash.save
    end
  end

  def test_create_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_queries_match(%r{/\*application:active_record\*/}) do
      Dashboard.create(name: "Another dashboard")
    end
  end

  def test_select_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_queries_match(%r{/\*application:active_record\*/}) do
      Dashboard.all.to_a
    end
  end

  def test_retrieves_comment_from_cache_when_enabled_and_set
    ActiveRecord::QueryLogs.cache_query_log_tags = true
    i = 0
    ActiveRecord::QueryLogs.tags = [ { query_counter: -> { i += 1 } } ]

    assert_queries_match("SELECT 1 /*query_counter:1*/") do
      ActiveRecord::Base.lease_connection.execute "SELECT 1"
    end

    assert_queries_match("SELECT 1 /*query_counter:1*/") do
      ActiveRecord::Base.lease_connection.execute "SELECT 1"
    end
  end

  def test_resets_cache_on_context_update
    ActiveRecord::QueryLogs.cache_query_log_tags = true
    ActiveSupport::ExecutionContext[:temporary] = "value"
    ActiveRecord::QueryLogs.tags = [ temporary_tag: ->(context) { context[:temporary] } ]

    assert_queries_match("SELECT 1 /*temporary_tag:value*/") do
      ActiveRecord::Base.lease_connection.execute "SELECT 1"
    end

    ActiveSupport::ExecutionContext[:temporary] = "new_value"

    assert_queries_match("SELECT 1 /*temporary_tag:new_value*/") do
      ActiveRecord::Base.lease_connection.execute "SELECT 1"
    end
  end

  def test_default_tag_behavior
    ActiveRecord::QueryLogs.tags = [:application, :foo]
    ActiveSupport::ExecutionContext.set(foo: "bar") do
      assert_queries_match(%r{/\*application:active_record,foo:bar\*/}) do
        Dashboard.first
      end
    end
    assert_queries_match(%r{/\*application:active_record\*/}) do
      Dashboard.first
    end
  end

  def test_connection_is_passed_to_tagging_proc
    connection = ActiveRecord::Base.lease_connection
    ActiveRecord::QueryLogs.tags = [ same_connection: ->(context) { context[:connection] == connection } ]

    assert_queries_match("SELECT 1 /*same_connection:true*/") do
      connection.execute "SELECT 1"
    end
  end

  def test_connection_does_not_override_already_existing_connection_in_context
    fake_connection = Object.new
    ActiveSupport::ExecutionContext[:connection] = fake_connection
    ActiveRecord::QueryLogs.tags = [ fake_connection: ->(context) { context[:connection] == fake_connection } ]

    assert_queries_match("SELECT 1 /*fake_connection:true*/") do
      ActiveRecord::Base.lease_connection.execute "SELECT 1"
    end
  end

  def test_empty_comments_are_not_added
    ActiveRecord::QueryLogs.tags = [ empty: -> { nil } ]
    assert_queries_match(%r{select id from posts$}) do
      ActiveRecord::Base.lease_connection.execute "select id from posts"
    end
  end

  def test_sql_commenter_format
    ActiveRecord::QueryLogs.tags_formatter = :sqlcommenter
    ActiveRecord::QueryLogs.tags = [:application]

    assert_queries_match(%r{/\*application='active_record'\*/}) do
      Dashboard.first
    end
  end

  def test_custom_basic_tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_string: "test content" } ]

    assert_queries_match(%r{/\*application:active_record,custom_string:test content\*/}) do
      Dashboard.first
    end
  end

  def test_custom_proc_tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_proc: -> { "test content" } } ]

    assert_queries_match(%r{/\*application:active_record,custom_proc:test content\*/}) do
      Dashboard.first
    end
  end

  def test_multiple_custom_tags
    ActiveRecord::QueryLogs.tags = [
      :application,
      { custom_proc: -> { "test content" }, another_proc: -> { "more test content" } },
    ]

    assert_queries_match(%r{/\*another_proc:more test content,application:active_record,custom_proc:test content\*/}) do
      Dashboard.first
    end
  end

  def test_sqlcommenter_format_value
    ActiveRecord::QueryLogs.tags_formatter = :sqlcommenter

    ActiveRecord::QueryLogs.tags = [
      :application,
      { tracestate: "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7", custom_proc: -> { "Joe's Shack" } },
    ]

    assert_queries_match(%r{custom_proc='Joe%27s%20Shack',tracestate='congo%3Dt61rcWkgMzE%2Crojo%3D00f067aa0ba902b7'\*/}) do
      Dashboard.first
    end
  end

  def test_sqlcommenter_format_allows_string_keys
    ActiveRecord::QueryLogs.tags_formatter = :sqlcommenter

    ActiveRecord::QueryLogs.tags = [
      :application,
      {
        "string" => "value",
        tracestate: "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7",
        custom_proc: -> { "Joe's Shack" }
      },
    ]

    assert_queries_match(%r{custom_proc='Joe%27s%20Shack',string='value',tracestate='congo%3Dt61rcWkgMzE%2Crojo%3D00f067aa0ba902b7'\*/}) do
      Dashboard.first
    end
  end

  def test_sqlcommenter_format_value_string_coercible
    ActiveRecord::QueryLogs.tags_formatter = :sqlcommenter

    ActiveRecord::QueryLogs.tags = [
      :application,
      { custom_proc: -> { 1234 } },
    ]

    assert_queries_match(%r{custom_proc='1234'\*/}) do
      Dashboard.first
    end
  end

  # PostgreSQL does validate the query encoding. Other adapters don't care.
  unless current_adapter?(:PostgreSQLAdapter)
    def test_invalid_encoding_query
      ActiveRecord::QueryLogs.tags = [ :application ]
      assert_nothing_raised do
        ActiveRecord::Base.lease_connection.execute "select 1 as '\xFF'"
      end
    end
  end

  def test_custom_proc_context_tags
    ActiveSupport::ExecutionContext[:foo] = "bar"
    ActiveRecord::QueryLogs.tags = [ :application, { custom_context_proc: ->(context) { context[:foo] } } ]

    assert_queries_match(%r{/\*application:active_record,custom_context_proc:bar\*/}) do
      Dashboard.first
    end
  end
end
