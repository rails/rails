# frozen_string_literal: true

require "cases/helper"
require "models/dashboard"

class QueryLogsTest < ActiveRecord::TestCase
  fixtures :dashboards

  ActiveRecord::QueryLogs.taggings[:application] = -> {
    "active_record"
  }

  def setup
    # ActiveSupport::ExecutionContext context is automatically reset in Rails app via an executor hooks set in railtie
    # But not in Active Record's own test suite.
    ActiveSupport::ExecutionContext.clear

    # Enable the query tags logging
    @original_transformers = ActiveRecord.query_transformers
    @original_prepend = ActiveRecord::QueryLogs.prepend_comment
    @original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord.query_transformers += [ActiveRecord::QueryLogs]
    ActiveRecord::QueryLogs.prepend_comment = false
    ActiveRecord::QueryLogs.cache_query_log_tags = false
    ActiveRecord::QueryLogs.cached_comment = nil
  end

  def teardown
    ActiveRecord.query_transformers = @original_transformers
    ActiveRecord::QueryLogs.prepend_comment = @original_prepend
    ActiveRecord::QueryLogs.tags = @original_tags
    ActiveRecord::QueryLogs.prepend_comment = false
    ActiveRecord::QueryLogs.cache_query_log_tags = false
    ActiveRecord::QueryLogs.cached_comment = nil
    # ActiveSupport::ExecutionContext context is automatically reset in Rails app via an executor hooks set in railtie
    # But not in Active Record's own test suite.
    ActiveSupport::ExecutionContext.clear
  end

  def test_escaping_good_comment
    assert_equal "app:foo", ActiveRecord::QueryLogs.send(:escape_sql_comment, "app:foo")
  end

  def test_escaping_bad_comments
    assert_equal "; DROP TABLE USERS;", ActiveRecord::QueryLogs.send(:escape_sql_comment, "*/; DROP TABLE USERS;/*")
    assert_equal "; DROP TABLE USERS;", ActiveRecord::QueryLogs.send(:escape_sql_comment, "**//; DROP TABLE USERS;/*")
  end

  def test_basic_commenting
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_sql(%r{select id from posts /\*application:active_record\*/$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  end

  def test_add_comments_to_beginning_of_query
    ActiveRecord::QueryLogs.tags = [ :application ]
    ActiveRecord::QueryLogs.prepend_comment = true

    assert_sql(%r{/\*application:active_record\*/ select id from posts$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  end

  def test_exists_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]
    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.exists?
    end
  end

  def test_delete_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]
    record = Dashboard.first

    assert_sql(%r{/\*application:active_record\*/}) do
      record.destroy
    end
  end

  def test_update_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_sql(%r{/\*application:active_record\*/}) do
      dash = Dashboard.first
      dash.name = "New name"
      dash.save
    end
  end

  def test_create_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.create(name: "Another dashboard")
    end
  end

  def test_select_is_commented
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.all.to_a
    end
  end

  def test_retrieves_comment_from_cache_when_enabled_and_set
    ActiveRecord::QueryLogs.cache_query_log_tags = true
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_equal "/*application:active_record*/", ActiveRecord::QueryLogs.call("")

    ActiveRecord::QueryLogs.stub(:cached_comment, "/*cached_comment*/") do
      assert_equal "/*cached_comment*/", ActiveRecord::QueryLogs.call("")
    end
  end

  def test_resets_cache_on_context_update
    ActiveRecord::QueryLogs.cache_query_log_tags = true
    ActiveSupport::ExecutionContext[:temporary] = "value"
    ActiveRecord::QueryLogs.tags = [ temporary_tag: ->(context) { context[:temporary] } ]

    assert_equal "/*temporary_tag:value*/", ActiveRecord::QueryLogs.call("")

    ActiveSupport::ExecutionContext[:temporary] = "new_value"

    assert_nil ActiveRecord::QueryLogs.cached_comment
    assert_equal "/*temporary_tag:new_value*/", ActiveRecord::QueryLogs.call("")
  end

  def test_default_tag_behavior
    ActiveRecord::QueryLogs.tags = [:application, :foo]
    ActiveSupport::ExecutionContext.set(foo: "bar") do
      assert_sql(%r{/\*application:active_record,foo:bar\*/}) do
        Dashboard.first
      end
    end
    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.first
    end
  end

  def test_empty_comments_are_not_added
    ActiveRecord::QueryLogs.tags = [ empty: -> { nil } ]
    assert_sql(%r{select id from posts$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  end

  def test_custom_basic_tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_string: "test content" } ]

    assert_sql(%r{/\*application:active_record,custom_string:test content\*/}) do
      Dashboard.first
    end
  end

  def test_custom_proc_tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_proc: -> { "test content" } } ]

    assert_sql(%r{/\*application:active_record,custom_proc:test content\*/}) do
      Dashboard.first
    end
  end

  def test_multiple_custom_tags
    ActiveRecord::QueryLogs.tags = [
      :application,
      { custom_proc: -> { "test content" }, another_proc: -> { "more test content" } },
    ]

    assert_sql(%r{/\*application:active_record,custom_proc:test content,another_proc:more test content\*/}) do
      Dashboard.first
    end
  end

  def test_custom_proc_context_tags
    ActiveSupport::ExecutionContext[:foo] = "bar"
    ActiveRecord::QueryLogs.tags = [ :application, { custom_context_proc: ->(context) { context[:foo] } } ]

    assert_sql(%r{/\*application:active_record,custom_context_proc:bar\*/}) do
      Dashboard.first
    end
  end
end
