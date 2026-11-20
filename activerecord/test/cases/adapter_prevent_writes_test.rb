# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/book"
require "models/post"
require "models/author"
require "models/event"

module ActiveRecord
  class AdapterPreventWritesTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.lease_connection
    end

    def test_preventing_writes_predicate
      assert_not_predicate @connection, :preventing_writes?

      ActiveRecord::Base.while_preventing_writes do
        assert_predicate @connection, :preventing_writes?
      end

      assert_not_predicate @connection, :preventing_writes?
    end

    def test_errors_when_an_insert_query_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")
        end
      end
    end

    def test_errors_when_an_update_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.update("UPDATE subscribers SET nick = '9989' WHERE nick = '138853948594'")
        end
      end
    end

    def test_errors_when_a_delete_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.delete("DELETE FROM subscribers WHERE nick = '138853948594'")
        end
      end
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_doesnt_error_when_a_select_query_has_encoding_errors
        ActiveRecord::Base.while_preventing_writes do
          # Contrary to other adapters, PostgreSQL will eagerly fail on encoding errors.
          # But at least we can assert it fails in the client and not before when trying to
          # match the query.
          assert_raises ActiveRecord::StatementInvalid do
            @connection.select_all("SELECT '\xC8'")
          end
        end
      end
    else
      def test_doesnt_error_when_a_select_query_has_encoding_errors
        ActiveRecord::Base.while_preventing_writes do
          assert_nothing_raised do
            @connection.select_all("SELECT '\xC8'")
          end
        end
      end
    end

    def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = '138853948594'")
        assert_equal 1, result.length
      end
    end

    if ActiveRecord::Base.lease_connection.supports_common_table_expressions?
      def test_doesnt_error_when_a_read_query_with_a_cte_is_called_while_preventing_writes
        @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

        ActiveRecord::Base.while_preventing_writes do
          result = @connection.select_all(<<~SQL)
            WITH matching_subscribers AS (SELECT subscribers.* FROM subscribers WHERE nick = '138853948594')
            SELECT * FROM matching_subscribers
          SQL
          assert_equal 1, result.length
        end
      end

      def test_errors_when_a_delete_query_is_called_through_a_cte_while_preventing_writes
        @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

        ActiveRecord::Base.while_preventing_writes do
          assert_raises(ActiveRecord::ReadOnlyError) do
            @connection.select_all(<<~SQL)
              WITH deleted_subscriber AS (DELETE FROM subscribers WHERE nick = '138853948594' RETURNING *)
              SELECT * FROM deleted_subscriber
            SQL
          end
        end

        assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM subscribers")
      end

      def test_errors_when_a_delete_query_follows_a_read_cte_while_preventing_writes
        @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

        ActiveRecord::Base.while_preventing_writes do
          assert_raises(ActiveRecord::ReadOnlyError) do
            @connection.select_all(<<~SQL)
              WITH x AS (SELECT 'LIMIT')
              DELETE FROM subscribers WHERE nick = '138853948594'
            SQL
          end
        end

        assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM subscribers")
      end
    end

    def test_errors_when_a_delete_query_follows_a_select_in_a_multi_statement_query_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.select_all("SELECT 1; DELETE FROM subscribers WHERE nick = '138853948594'")
        end
      end

      assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM subscribers")
    end

    def test_doesnt_error_when_a_select_query_contains_a_semicolon_in_a_string_literal_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('a;b')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = 'a;b'")
        assert_equal 1, result.length
      end
    end

    def test_doesnt_error_when_a_select_query_contains_write_keywords_in_a_string_literal_or_comment_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('DELETE')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = 'DELETE'")
        assert_equal 1, result.length

        result = @connection.select_all("-- DELETE FROM subscribers\nSELECT subscribers.* FROM subscribers WHERE nick = 'DELETE'")
        assert_equal 1, result.length

        result = @connection.select_all("/* DELETE FROM subscribers */ SELECT subscribers.* FROM subscribers WHERE nick = 'DELETE'")
        assert_equal 1, result.length
      end
    end

    def test_doesnt_error_when_a_select_query_ends_with_a_semicolon_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("SELECT subscribers.* FROM subscribers WHERE nick = '138853948594';")
        assert_equal 1, result.length
      end
    end

    def test_doesnt_error_when_a_select_query_starting_with_a_slash_star_comment_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("/* some comment */ SELECT subscribers.* FROM subscribers WHERE nick = '138853948594'")
        assert_equal 1, result.length
      end
    end

    def test_errors_when_an_insert_query_prefixed_by_a_slash_star_comment_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.insert("/* some comment */ INSERT INTO subscribers(nick) VALUES ('138853948594')")
        end
      end
    end

    def test_doesnt_error_when_a_select_query_starting_with_double_dash_comments_is_called_while_preventing_writes
      @connection.insert("INSERT INTO subscribers(nick) VALUES ('138853948594')")

      ActiveRecord::Base.while_preventing_writes do
        result = @connection.select_all("-- some comment\n-- comment about INSERT\nSELECT subscribers.* FROM subscribers WHERE nick = '138853948594'")
        assert_equal 1, result.length
      end
    end

    def test_errors_when_an_insert_query_prefixed_by_a_double_dash_comment_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.insert("-- some comment\nINSERT INTO subscribers(nick) VALUES ('138853948594')")
        end
      end
    end

    def test_errors_when_an_insert_query_prefixed_by_a_multiline_double_dash_comment_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          Timeout.timeout(0.1) do # should be fast to parse the query
            @connection.insert("#{"-- comment\n" * 50}INSERT INTO subscribers(nick) VALUES ('138853948594')")
          end
        end
      end
    end

    def test_errors_when_an_insert_query_prefixed_by_a_slash_star_comment_containing_read_command_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.insert("/* SELECT */ INSERT INTO subscribers(nick) VALUES ('138853948594')")
        end
      end
    end

    def test_errors_when_an_insert_query_prefixed_by_a_double_dash_comment_containing_read_command_is_called_while_preventing_writes
      ActiveRecord::Base.while_preventing_writes do
        assert_raises(ActiveRecord::ReadOnlyError) do
          @connection.insert("-- SELECT\nINSERT INTO subscribers(nick) VALUES ('138853948594')")
        end
      end
    end
  end
end
