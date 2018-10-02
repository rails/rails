# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/book"
require "models/post"
require "models/author"
require "models/event"

module ActiveRecord
  class AdapterTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
      @connection.materialize_transactions
    end

    ##
    # PostgreSQL does not support null bytes in strings
    unless current_adapter?(:PostgreSQLAdapter) ||
        (current_adapter?(:SQLite3Adapter) && !ActiveRecord::Base.connection.prepared_statements)
      def test_update_prepared_statement
        b = Book.create(name: "my \x00 book")
        b.reload
        assert_equal "my \x00 book", b.name
        b.update(name: "my other \x00 book")
        b.reload
        assert_equal "my other \x00 book", b.name
      end
    end

    def test_create_record_with_pk_as_zero
      Book.create(id: 0)
      assert_equal 0, Book.find(0).id
      assert_nothing_raised { Book.destroy(0) }
    end

    def test_valid_column
      @connection.native_database_types.each_key do |type|
        assert @connection.valid_type?(type)
      end
    end

    def test_invalid_column
      assert_not @connection.valid_type?(:foobar)
    end

    def test_tables
      tables = @connection.tables
      assert_includes tables, "accounts"
      assert_includes tables, "authors"
      assert_includes tables, "tasks"
      assert_includes tables, "topics"
    end

    def test_table_exists?
      assert @connection.table_exists?("accounts")
      assert @connection.table_exists?(:accounts)
      assert_not @connection.table_exists?("nonexistingtable")
      assert_not @connection.table_exists?("'")
      assert_not @connection.table_exists?(nil)
    end

    def test_data_sources
      data_sources = @connection.data_sources
      assert_includes data_sources, "accounts"
      assert_includes data_sources, "authors"
      assert_includes data_sources, "tasks"
      assert_includes data_sources, "topics"
    end

    def test_data_source_exists?
      assert @connection.data_source_exists?("accounts")
      assert @connection.data_source_exists?(:accounts)
      assert_not @connection.data_source_exists?("nonexistingtable")
      assert_not @connection.data_source_exists?("'")
      assert_not @connection.data_source_exists?(nil)
    end

    def test_indexes
      idx_name = "accounts_idx"

      indexes = @connection.indexes("accounts")
      assert_empty indexes

      @connection.add_index :accounts, :firm_id, name: idx_name
      indexes = @connection.indexes("accounts")
      assert_equal "accounts", indexes.first.table
      assert_equal idx_name, indexes.first.name
      assert_not indexes.first.unique
      assert_equal ["firm_id"], indexes.first.columns
    ensure
      @connection.remove_index(:accounts, name: idx_name) rescue nil
    end

    def test_remove_index_when_name_and_wrong_column_name_specified
      index_name = "accounts_idx"

      @connection.add_index :accounts, :firm_id, name: index_name
      assert_raises ArgumentError do
        @connection.remove_index :accounts, name: index_name, column: :wrong_column_name
      end
    ensure
      @connection.remove_index(:accounts, name: index_name)
    end

    def test_current_database
      if @connection.respond_to?(:current_database)
        assert_equal ARTest.connection_config["arunit"]["database"], @connection.current_database
      end
    end

    if current_adapter?(:Mysql2Adapter)
      def test_charset
        assert_not_nil @connection.charset
        assert_not_equal "character_set_database", @connection.charset
        assert_equal @connection.show_variable("character_set_database"), @connection.charset
      end

      def test_collation
        assert_not_nil @connection.collation
        assert_not_equal "collation_database", @connection.collation
        assert_equal @connection.show_variable("collation_database"), @connection.collation
      end

      def test_show_nonexistent_variable_returns_nil
        assert_nil @connection.show_variable("foo_bar_baz")
      end

      def test_not_specifying_database_name_for_cross_database_selects
        begin
          assert_nothing_raised do
            ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations["arunit"].except(:database))

            config = ARTest.connection_config
            ActiveRecord::Base.connection.execute(
              "SELECT #{config['arunit']['database']}.pirates.*, #{config['arunit2']['database']}.courses.* " \
              "FROM #{config['arunit']['database']}.pirates, #{config['arunit2']['database']}.courses"
            )
          end
        ensure
          ActiveRecord::Base.establish_connection :arunit
        end
      end
    end

    def test_table_alias
      def @connection.test_table_alias_length() 10; end
      class << @connection
        alias_method :old_table_alias_length, :table_alias_length
        alias_method :table_alias_length,     :test_table_alias_length
      end

      assert_equal "posts",      @connection.table_alias_for("posts")
      assert_equal "posts_comm", @connection.table_alias_for("posts_comments")
      assert_equal "dbo_posts",  @connection.table_alias_for("dbo.posts")

      class << @connection
        remove_method :table_alias_length
        alias_method :table_alias_length, :old_table_alias_length
      end
    end

    def test_uniqueness_violations_are_translated_to_specific_exception
      @connection.execute "INSERT INTO subscribers(nick) VALUES('me')"
      error = assert_raises(ActiveRecord::RecordNotUnique) do
        @connection.execute "INSERT INTO subscribers(nick) VALUES('me')"
      end

      assert_not_nil error.cause
    end

    def test_not_null_violations_are_translated_to_specific_exception
      error = assert_raises(ActiveRecord::NotNullViolation) do
        Post.create
      end

      assert_not_nil error.cause
    end

    unless current_adapter?(:SQLite3Adapter)
      def test_value_limit_violations_are_translated_to_specific_exception
        error = assert_raises(ActiveRecord::ValueTooLong) do
          Event.create(title: "abcdefgh")
        end

        assert_not_nil error.cause
      end

      def test_numeric_value_out_of_ranges_are_translated_to_specific_exception
        error = assert_raises(ActiveRecord::RangeError) do
          Book.connection.create("INSERT INTO books(author_id) VALUES (9223372036854775808)")
        end

        assert_not_nil error.cause
      end
    end

    def test_exceptions_from_notifications_are_not_translated
      original_error = StandardError.new("This StandardError shouldn't get translated")
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { raise original_error }
      actual_error = assert_raises(StandardError) do
        @connection.execute("SELECT * FROM posts")
      end

      assert_equal original_error, actual_error

    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_database_related_exceptions_are_translated_to_statement_invalid
      error = assert_raises(ActiveRecord::StatementInvalid) do
        @connection.execute("This is a syntax error")
      end

      assert_instance_of ActiveRecord::StatementInvalid, error
      assert_kind_of Exception, error.cause
    end

    def test_select_all_always_return_activerecord_result
      result = @connection.select_all "SELECT * FROM posts"
      assert result.is_a?(ActiveRecord::Result)
    end

    if ActiveRecord::Base.connection.prepared_statements
      def test_select_all_with_legacy_binds
        post = Post.create!(title: "foo", body: "bar")
        expected = @connection.select_all("SELECT * FROM posts WHERE id = #{post.id}")
        result = @connection.select_all("SELECT * FROM posts WHERE id = #{Arel::Nodes::BindParam.new(nil).to_sql}", nil, [[nil, post.id]])
        assert_equal expected.to_a, result.to_a
      end

      def test_insert_update_delete_with_legacy_binds
        binds = [[nil, 1]]
        bind_param = Arel::Nodes::BindParam.new(nil)

        id = @connection.insert("INSERT INTO events(id) VALUES (#{bind_param.to_sql})", nil, nil, nil, nil, binds)
        assert_equal 1, id

        @connection.update("UPDATE events SET title = 'foo' WHERE id = #{bind_param.to_sql}", nil, binds)
        result = @connection.select_all("SELECT * FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        assert_equal({ "id" => 1, "title" => "foo" }, result.first)

        @connection.delete("DELETE FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        result = @connection.select_all("SELECT * FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        assert_nil result.first
      end

      def test_insert_update_delete_with_binds
        binds = [Relation::QueryAttribute.new("id", 1, Type.default_value)]
        bind_param = Arel::Nodes::BindParam.new(nil)

        id = @connection.insert("INSERT INTO events(id) VALUES (#{bind_param.to_sql})", nil, nil, nil, nil, binds)
        assert_equal 1, id

        @connection.update("UPDATE events SET title = 'foo' WHERE id = #{bind_param.to_sql}", nil, binds)
        result = @connection.select_all("SELECT * FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        assert_equal({ "id" => 1, "title" => "foo" }, result.first)

        @connection.delete("DELETE FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        result = @connection.select_all("SELECT * FROM events WHERE id = #{bind_param.to_sql}", nil, binds)
        assert_nil result.first
      end
    end

    def test_select_methods_passing_a_association_relation
      author = Author.create!(name: "john")
      Post.create!(author: author, title: "foo", body: "bar")
      query = author.posts.where(title: "foo").select(:title)
      assert_equal({ "title" => "foo" }, @connection.select_one(query))
      assert @connection.select_all(query).is_a?(ActiveRecord::Result)
      assert_equal "foo", @connection.select_value(query)
      assert_equal ["foo"], @connection.select_values(query)
    end

    def test_select_methods_passing_a_relation
      Post.create!(title: "foo", body: "bar")
      query = Post.where(title: "foo").select(:title)
      assert_equal({ "title" => "foo" }, @connection.select_one(query))
      assert @connection.select_all(query).is_a?(ActiveRecord::Result)
      assert_equal "foo", @connection.select_value(query)
      assert_equal ["foo"], @connection.select_values(query)
    end

    test "type_to_sql returns a String for unmapped types" do
      assert_equal "special_db_type", @connection.type_to_sql(:special_db_type)
    end

    unless current_adapter?(:PostgreSQLAdapter)
      def test_log_invalid_encoding
        error = assert_raises RuntimeError do
          @connection.send :log, "SELECT 'ы' FROM DUAL" do
            raise (+"ы").force_encoding(Encoding::ASCII_8BIT)
          end
        end

        assert_equal "ы", error.message
      end
    end

    def test_supports_multi_insert_is_deprecated
      assert_deprecated { @connection.supports_multi_insert? }
    end

    def test_column_name_length_is_deprecated
      assert_deprecated { @connection.column_name_length }
    end

    def test_table_name_length_is_deprecated
      assert_deprecated { @connection.table_name_length }
    end

    def test_columns_per_table_is_deprecated
      assert_deprecated { @connection.columns_per_table }
    end

    def test_indexes_per_table_is_deprecated
      assert_deprecated { @connection.indexes_per_table }
    end

    def test_columns_per_multicolumn_index_is_deprecated
      assert_deprecated { @connection.columns_per_multicolumn_index }
    end

    def test_sql_query_length_is_deprecated
      assert_deprecated { @connection.sql_query_length }
    end

    def test_joins_per_query_is_deprecated
      assert_deprecated { @connection.joins_per_query }
    end
  end

  class AdapterForeignKeyTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :fk_test_has_pk

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_foreign_key_violations_are_translated_to_specific_exception_with_validate_false
      klass_has_fk = Class.new(ActiveRecord::Base) do
        self.table_name = "fk_test_has_fk"
      end

      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        has_fk = klass_has_fk.new
        has_fk.fk_id = 1231231231
        has_fk.save(validate: false)
      end

      assert_not_nil error.cause
    end

    def test_foreign_key_violations_on_insert_are_translated_to_specific_exception
      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        insert_into_fk_test_has_fk
      end

      assert_not_nil error.cause
    end

    def test_foreign_key_violations_on_delete_are_translated_to_specific_exception
      insert_into_fk_test_has_fk fk_id: 1

      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.execute "DELETE FROM fk_test_has_pk WHERE pk_id = 1"
      end

      assert_not_nil error.cause
    end

    def test_disable_referential_integrity
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          insert_into_fk_test_has_fk
          # should delete created record as otherwise disable_referential_integrity will try to enable constraints
          # after executed block and will fail (at least on Oracle)
          @connection.execute "DELETE FROM fk_test_has_fk"
        end
      end
    end

    private
      def insert_into_fk_test_has_fk(fk_id: 0)
        # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
        if @connection.prefetch_primary_key?
          id_value = @connection.next_sequence_value(@connection.default_sequence_name("fk_test_has_fk", "id"))
          @connection.execute "INSERT INTO fk_test_has_fk (id,fk_id) VALUES (#{id_value},#{fk_id})"
        else
          @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (#{fk_id})"
        end
      end
  end

  class AdapterTestWithoutTransaction < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class Klass < ActiveRecord::Base
    end

    def setup
      Klass.establish_connection :arunit
      @connection = Klass.connection
    end

    teardown do
      Klass.remove_connection
    end

    unless in_memory_db?
      test "transaction state is reset after a reconnect" do
        @connection.begin_transaction
        assert_predicate @connection, :transaction_open?
        @connection.reconnect!
        assert_not_predicate @connection, :transaction_open?
      end

      test "transaction state is reset after a disconnect" do
        @connection.begin_transaction
        assert_predicate @connection, :transaction_open?
        @connection.disconnect!
        assert_not_predicate @connection, :transaction_open?
      end
    end

    # test resetting sequences in odd tables in PostgreSQL
    if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
      require "models/movie"
      require "models/subscriber"

      def test_reset_empty_table_with_custom_pk
        Movie.delete_all
        Movie.connection.reset_pk_sequence! "movies"
        assert_equal 1, Movie.create(name: "fight club").id
      end

      def test_reset_table_with_non_integer_pk
        Subscriber.delete_all
        Subscriber.connection.reset_pk_sequence! "subscribers"
        sub = Subscriber.new(name: "robert drake")
        sub.id = "bob drake"
        assert_nothing_raised { sub.save! }
      end
    end
  end
end

if ActiveRecord::Base.connection.supports_advisory_locks?
  class AdvisoryLocksEnabledTest < ActiveRecord::TestCase
    include ConnectionHelper

    def test_advisory_locks_enabled?
      assert ActiveRecord::Base.connection.advisory_locks_enabled?

      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(
          orig_connection.merge(advisory_locks: false)
        )

        assert_not ActiveRecord::Base.connection.advisory_locks_enabled?

        ActiveRecord::Base.establish_connection(
          orig_connection.merge(advisory_locks: true)
        )

        assert ActiveRecord::Base.connection.advisory_locks_enabled?
      end
    end
  end
end
