# frozen_string_literal: true

require "cases/helper"
require "models/dashboard"

class QueryLogTagsTest < ActiveRecord::TestCase
  fixtures :dashboards

  def setup
    @original_enabled = ActiveRecord::Base.query_log_tags_enabled
    ActiveRecord::Base.query_log_tags_enabled = true
    if @original_enabled == false
      # if we haven't enabled the feature, the execution methods need to be prepended at run time
      ActiveRecord::Base.connection.class_eval do
        prepend(ActiveRecord::ConnectionAdapters::QueryLogTags::ExecutionMethods)
      end
    end
    @original_prepend = ActiveRecord::Base.connection.prepend_comment
    ActiveRecord::Base.connection.prepend_comment = false
    @original_application_name = log_tag_context.send(:context)[:application_name]
    log_tag_context.update(application_name: "active_record")
    log_tag_context.cache_query_log_tags = false
    log_tag_context.clear_comment_cache!
  end

  def teardown
    ActiveRecord::Base.query_log_tags_enabled = @original_enabled
    ActiveRecord::Base.connection.prepend_comment = @original_prepend
    log_tag_context.update(application_name: @original_application_name)
    log_tag_context.components = []
  end

  def log_tag_context
    ActiveRecord::ConnectionAdapters::AbstractAdapter::QueryLogTagsContext
  end

  def test_escaping_good_comment
    assert_equal "app:foo", log_tag_context.send(:escape_sql_comment, "app:foo")
  end

  def test_escaping_bad_comments
    assert_equal "; DROP TABLE USERS;", log_tag_context.send(:escape_sql_comment, "*/; DROP TABLE USERS;/*")
    assert_equal "; DROP TABLE USERS;", log_tag_context.send(:escape_sql_comment, "**//; DROP TABLE USERS;/*")
  end

  def test_basic_commenting
    log_tag_context.components = [:application]

    assert_sql(%r{select id from posts /\*application:active_record\*/$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  end

  def test_add_comments_to_beginning_of_query
    log_tag_context.components = [:application]
    ActiveRecord::Base.connection.prepend_comment = true

    assert_sql(%r{/\*application:active_record\*/ select id from posts$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  ensure
    ActiveRecord::Base.connection.prepend_comment = nil
  end

  def test_exists_is_commented
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.exists?
    end
  end

  def test_delete_is_commented
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.first.destroy
    end
  end

  def test_update_is_commented
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/}) do
      dash = Dashboard.first
      dash.name = "New name"
      dash.save
    end
  end

  def test_create_is_commented
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.create(name: "Another dashboard")
    end
  end

  def test_select_is_commented
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/}) do
      Dashboard.all.to_a
    end
  end

  def test_last_line_component
    components = log_tag_context.components
    log_tag_context.components = [:line]

    assert_sql(%r{/\*line:#{__FILE__}:[0-9]+:in `block in test_last_line_component'\*/$}) do
      Dashboard.first
    end
  ensure
    log_tag_context.components = components
  end

  def test_pid
    components = log_tag_context.components
    log_tag_context.components = [:pid]

    assert_sql(%r{/\*pid:#{Process.pid}\*/$}) do
      Dashboard.first
    end
  ensure
    log_tag_context.components = components
  end

  def test_config_db_host
    skip if current_adapter?(:SQLite3Adapter)
    components = log_tag_context.components

    # mock the connection config to expose a socket value
    db_config = ActiveRecord::Base.connection.pool.db_config
    db_config.stub(:configuration_hash, { host: "localhost" }) do
      log_tag_context.components = [:db_host]

      assert_sql(%r{/\*db_host:localhost}) do
        Dashboard.first
      end
    end
  ensure
    log_tag_context.components = components || [:application]
  end

  def test_config_database
    log_tag_context.components = [:database]

    assert_sql(%r{/\*database:.*(fixture_database|activerecord_unittest|:memory:)+}) do
      Dashboard.first
    end
  end

  def test_config_socket
    skip unless current_adapter?(:Mysql2Adapter)
    components = log_tag_context.components
    # mock the connection config to expose a socket value
    db_config = ActiveRecord::Base.connection_db_config
    db_config.stub(:socket, "comment_test_socket") do
      log_tag_context.components = [:socket]

      assert_sql(%r{/\*socket:comment_test_socket}) do
        Dashboard.first
      end
    end
  ensure
    log_tag_context.components = components || [:application]
  end

  def test_retrieves_comment_from_cache_when_enabled_and_set
    log_tag_context.cache_query_log_tags = true
    log_tag_context.components = [:application]

    assert_equal "/*application:active_record*/", log_tag_context.comment

    log_tag_context.stub(:cached_comment, "/*cached_comment*/") do
      assert_equal "/*cached_comment*/", log_tag_context.comment
    end
  ensure
    log_tag_context.clear_comment_cache!
    log_tag_context.cache_query_log_tags = false
  end

  def test_resets_cache_on_context_update
    log_tag_context.cache_query_log_tags = true
    log_tag_context.components = [:application]

    assert_equal "/*application:active_record*/", log_tag_context.comment

    log_tag_context.update(application_name: "new_name")

    assert_nil log_tag_context.cached_comment
    assert_equal "/*application:new_name*/", log_tag_context.comment
  ensure
    log_tag_context.clear_comment_cache!
    log_tag_context.cache_query_log_tags = false
    log_tag_context.update(application_name: nil)
  end

  def test_ensure_context_has_symbol_keys
    log_tag_context.components = [:application]
    log_tag_context.update("application_name" => "symbolized")

    assert_sql(%r{/\*application:symbolized}) do
      Dashboard.first
    end
  ensure
    log_tag_context.update(application_name: nil)
  end

  def test_inline_annotations_only_affect_block
    # disable regular comment components
    log_tag_context.components = []

    # confirm single inline annotation
    assert_sql(%r{/\*foo\*/$}) do
      log_tag_context.with_annotation("foo") do
        Dashboard.first
      end
    end

    # confirm different inline annotation
    assert_sql(%r{/\*bar\*/$}) do
      log_tag_context.with_annotation("bar") do
        Dashboard.first
      end
    end

    # confirm no annotations are persisted
    log_tag_context.components = [:application]

    assert_sql(%r{/\*application:active_record\*/$}) do
      Dashboard.first
    end
  ensure
    log_tag_context.components = [:application]
  end

  def test_nested_inline_annotations
    assert_sql(%r{/\*foobar\*/$}) do
      log_tag_context.with_annotation("foo") do
        log_tag_context.with_annotation("bar") do
          Dashboard.first
        end
      end
    end
  end

  def test_bad_inline_annotations
    assert_sql(%r{/\*; DROP TABLE USERS;\*/$}) do
      log_tag_context.with_annotation("*/; DROP TABLE USERS;/*") do
        Dashboard.first
      end
    end

    assert_sql(%r{/\*; DROP TABLE USERS;\*/$}) do
      log_tag_context.with_annotation("**//; DROP TABLE USERS;//**") do
        Dashboard.first
      end
    end
  end

  def test_inline_annotations_are_deduped
    log_tag_context.components = [:application]
    assert_sql(%r{select id from posts /\*foo\*/ /\*application:active_record\*/$}) do
      log_tag_context.with_annotation("foo") do
        ActiveRecord::Base.connection.execute "select id from posts /*foo*/"
      end
    end
  end

  def test_empty_comments_are_not_added
    original_components = log_tag_context.components
    original_app_name = log_tag_context.send(:context)[:application_name]
    log_tag_context.components = [:application]
    log_tag_context.update(application_name: nil)
    assert_sql(%r{select id from posts$}) do
      ActiveRecord::Base.connection.execute "select id from posts"
    end
  ensure
    log_tag_context.components = original_components
    log_tag_context.update(application_name: original_app_name)
  end
end
