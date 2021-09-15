# frozen_string_literal: true

require "cases/helper"
require "models/dashboard"

class QueryLogsTest < ActiveRecord::TestCase
  fixtures :dashboards

  ActiveRecord::QueryLogs.taggings[:application] = -> {
    "active_record"
  }

  def setup
    # Enable the query tags logging
    @original_transformers = ActiveRecord.query_transformers
    @original_prepend = ActiveRecord::QueryLogs.prepend_comment
    ActiveRecord.query_transformers += [ActiveRecord::QueryLogs]
    ActiveRecord::QueryLogs.prepend_comment = false
    ActiveRecord::QueryLogs.cache_query_log_tags = false
    ActiveRecord::QueryLogs.cached_comment = nil
  end

  def teardown
    ActiveRecord.query_transformers = @original_transformers
    ActiveRecord::QueryLogs.prepend_comment = @original_prepend
    ActiveRecord::QueryLogs.tags = []
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
  ensure
    ActiveRecord::QueryLogs.prepend_comment = nil
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

    assert_equal " /*application:active_record*/", ActiveRecord::QueryLogs.call("")

    ActiveRecord::QueryLogs.stub(:cached_comment, "/*cached_comment*/") do
      assert_equal " /*cached_comment*/", ActiveRecord::QueryLogs.call("")
    end
  ensure
    ActiveRecord::QueryLogs.cached_comment = nil
    ActiveRecord::QueryLogs.cache_query_log_tags = false
  end

  def test_resets_cache_on_context_update
    ActiveRecord::QueryLogs.cache_query_log_tags = true
    ActiveRecord::QueryLogs.update_context(temporary: "value")
    ActiveRecord::QueryLogs.tags = [ temporary_tag: ->(context) { context[:temporary] } ]

    assert_equal " /*temporary_tag:value*/", ActiveRecord::QueryLogs.call("")

    ActiveRecord::QueryLogs.update_context(temporary: "new_value")

    assert_nil ActiveRecord::QueryLogs.cached_comment
    assert_equal " /*temporary_tag:new_value*/", ActiveRecord::QueryLogs.call("")
  ensure
    ActiveRecord::QueryLogs.cached_comment = nil
    ActiveRecord::QueryLogs.cache_query_log_tags = false
  end

  def test_ensure_context_has_symbol_keys
    ActiveRecord::QueryLogs.tags = [ new_key: ->(context) { context[:symbol_key] } ]
    ActiveRecord::QueryLogs.update_context("symbol_key" => "symbolized")

    assert_sql(%r{/\*new_key:symbolized}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.update_context(application_name: nil)
  end

  def test_default_tag_behavior
    ActiveRecord::QueryLogs.tags = [:application, :foo]
    ActiveRecord::QueryLogs.set_context(foo: "bar") do
      assert_sql(%r{/\*application:active_record,foo:bar\*/}) do
        Dashboard.first
      end
    end
    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.first
    end
  end

  def test_inline_tags_only_affect_block
    # disable regular comment tags
    ActiveRecord::QueryLogs.tags = []

    # confirm single inline tag
    assert_sql(%r{/\*foo\*/$}) do
      ActiveRecord::QueryLogs.with_tag("foo") do
        Dashboard.first
      end
    end

    # confirm different inline tag
    assert_sql(%r{/\*bar\*/$}) do
      ActiveRecord::QueryLogs.with_tag("bar") do
        Dashboard.first
      end
    end

    # confirm no tags are persisted
    ActiveRecord::QueryLogs.tags = [ :application ]

    assert_sql(%r{/\*application:active_record\*/$}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.tags = [ :application ]
  end

  def test_nested_inline_tags
    assert_sql(%r{/\*foobar\*/$}) do
      ActiveRecord::QueryLogs.with_tag("foo") do
        ActiveRecord::QueryLogs.with_tag("bar") do
          Dashboard.first
        end
      end
    end
  end

  def test_bad_inline_tags
    assert_sql(%r{/\*; DROP TABLE USERS;\*/$}) do
      ActiveRecord::QueryLogs.with_tag("*/; DROP TABLE USERS;/*") do
        Dashboard.first
      end
    end

    assert_sql(%r{/\*; DROP TABLE USERS;\*/$}) do
      ActiveRecord::QueryLogs.with_tag("**//; DROP TABLE USERS;//**") do
        Dashboard.first
      end
    end
  end

  def test_empty_comments_are_not_added
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.tags = [ empty: -> { nil } ]
    assert_sql(%r{select id from posts$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  ensure
    ActiveRecord::QueryLogs.tags = original_tags
  end

  def test_custom_basic_tags
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_string: "test content" } ]

    assert_sql(%r{/\*application:active_record,custom_string:test content\*/$}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.tags = original_tags
  end

  def test_custom_proc_tags
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.tags = [ :application, { custom_proc: -> { "test content" } } ]

    assert_sql(%r{/\*application:active_record,custom_proc:test content\*/$}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.tags = original_tags
  end

  def test_multiple_custom_tags
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.tags = [
      :application,
      { custom_proc: -> { "test content" }, another_proc: -> { "more test content" } },
    ]

    assert_sql(%r{/\*application:active_record,custom_proc:test content,another_proc:more test content\*/$}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.tags = original_tags
  end

  def test_custom_proc_context_tags
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.update_context(foo: "bar")
    ActiveRecord::QueryLogs.tags = [ :application, { custom_context_proc: ->(context) { context[:foo] } } ]

    assert_sql(%r{/\*application:active_record,custom_context_proc:bar\*/$}) do
      Dashboard.first
    end
  ensure
    ActiveRecord::QueryLogs.update_context(foo: nil)
    ActiveRecord::QueryLogs.tags = original_tags
  end

  def test_set_context_restore_state
    original_tags = ActiveRecord::QueryLogs.tags
    ActiveRecord::QueryLogs.tags = [foo: ->(context) { context[:foo] }]
    ActiveRecord::QueryLogs.set_context(foo: "bar") do
      assert_sql(%r{/\*foo:bar\*/$}) { Dashboard.first }
      ActiveRecord::QueryLogs.set_context(foo: "plop") do
        assert_sql(%r{/\*foo:plop\*/$}) { Dashboard.first }
      end
      assert_sql(%r{/\*foo:bar\*/$}) { Dashboard.first }
    end
  ensure
    ActiveRecord::QueryLogs.tags = original_tags
  end
end
