require "cases/helper"

module ActiveRecord
  class AdapterTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_tables
      tables = @connection.tables
      assert tables.include?("accounts")
      assert tables.include?("authors")
      assert tables.include?("tasks")
      assert tables.include?("topics")
    end

    def test_table_exists?
      assert @connection.table_exists?("accounts")
      assert !@connection.table_exists?("nonexistingtable")
      assert !@connection.table_exists?(nil)
    end

    def test_indexes
      idx_name = "accounts_idx"

      if @connection.respond_to?(:indexes)
        indexes = @connection.indexes("accounts")
        assert indexes.empty?

        @connection.add_index :accounts, :firm_id, :name => idx_name
        indexes = @connection.indexes("accounts")
        assert_equal "accounts", indexes.first.table
        # OpenBase does not have the concept of a named index
        # Indexes are merely properties of columns.
        assert_equal idx_name, indexes.first.name unless current_adapter?(:OpenBaseAdapter)
        assert !indexes.first.unique
        assert_equal ["firm_id"], indexes.first.columns
      else
        warn "#{@connection.class} does not respond to #indexes"
      end

    ensure
      @connection.remove_index(:accounts, :name => idx_name) rescue nil
    end

    def test_current_database
      if @connection.respond_to?(:current_database)
        assert_equal ARTest.connection_config['arunit']['database'], @connection.current_database
      end
    end

    if current_adapter?(:MysqlAdapter)
      def test_charset
        assert_not_nil @connection.charset
        assert_not_equal 'character_set_database', @connection.charset
        assert_equal @connection.show_variable('character_set_database'), @connection.charset
      end

      def test_collation
        assert_not_nil @connection.collation
        assert_not_equal 'collation_database', @connection.collation
        assert_equal @connection.show_variable('collation_database'), @connection.collation
      end

      def test_show_nonexistent_variable_returns_nil
        assert_nil @connection.show_variable('foo_bar_baz')
      end

      def test_not_specifying_database_name_for_cross_database_selects
        begin
          assert_nothing_raised do
            ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['arunit'].except(:database))

            config = ARTest.connection_config
            ActiveRecord::Base.connection.execute(
              "SELECT #{config['arunit']['database']}.pirates.*, #{config['arunit2']['database']}.courses.* " \
              "FROM #{config['arunit']['database']}.pirates, #{config['arunit2']['database']}.courses"
            )
          end
        ensure
          ActiveRecord::Base.establish_connection 'arunit'
        end
      end
    end

    def test_table_alias
      def @connection.test_table_alias_length() 10; end
      class << @connection
        alias_method :old_table_alias_length, :table_alias_length
        alias_method :table_alias_length,     :test_table_alias_length
      end

      assert_equal 'posts',      @connection.table_alias_for('posts')
      assert_equal 'posts_comm', @connection.table_alias_for('posts_comments')
      assert_equal 'dbo_posts',  @connection.table_alias_for('dbo.posts')

      class << @connection
        remove_method :table_alias_length
        alias_method :table_alias_length, :old_table_alias_length
      end
    end

    # test resetting sequences in odd tables in postgreSQL
    if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
      require 'models/movie'
      require 'models/subscriber'

      def test_reset_empty_table_with_custom_pk
        Movie.delete_all
        Movie.connection.reset_pk_sequence! 'movies'
        assert_equal 1, Movie.create(:name => 'fight club').id
      end

      if ActiveRecord::Base.connection.adapter_name != "FrontBase"
        def test_reset_table_with_non_integer_pk
          Subscriber.delete_all
          Subscriber.connection.reset_pk_sequence! 'subscribers'
          sub = Subscriber.new(:name => 'robert drake')
          sub.id = 'bob drake'
          assert_nothing_raised { sub.save! }
        end
      end
    end

    def test_uniqueness_violations_are_translated_to_specific_exception
      @connection.execute "INSERT INTO subscribers(nick) VALUES('me')"
      assert_raises(ActiveRecord::RecordNotUnique) do
        @connection.execute "INSERT INTO subscribers(nick) VALUES('me')"
      end
    end

    def test_foreign_key_violations_are_translated_to_specific_exception
      unless @connection.adapter_name == 'SQLite'
        assert_raises(ActiveRecord::InvalidForeignKey) do
          # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
          if @connection.prefetch_primary_key?
            id_value = @connection.next_sequence_value(@connection.default_sequence_name("fk_test_has_fk", "id"))
            @connection.execute "INSERT INTO fk_test_has_fk (id, fk_id) VALUES (#{id_value},0)"
          else
            @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (0)"
          end
        end
      end
    end

    def test_disable_referential_integrity
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
          if @connection.prefetch_primary_key?
            id_value = @connection.next_sequence_value(@connection.default_sequence_name("fk_test_has_fk", "id"))
            @connection.execute "INSERT INTO fk_test_has_fk (id, fk_id) VALUES (#{id_value},0)"
          else
            @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (0)"
          end
          # should deleted created record as otherwise disable_referential_integrity will try to enable contraints after executed block
          # and will fail (at least on Oracle)
          @connection.execute "DELETE FROM fk_test_has_fk"
        end
      end
    end
  end

  class AdapterTestWithoutTransaction < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    class Klass < ActiveRecord::Base
    end

    def setup
      Klass.establish_connection 'arunit'
      @connection = Klass.connection
    end

    def teardown
      Klass.remove_connection
    end

    test "transaction state is reset after a reconnect" do
      skip "in-memory db doesn't allow reconnect" if in_memory_db?

      @connection.begin_transaction
      assert @connection.transaction_open?
      @connection.reconnect!
      assert !@connection.transaction_open?
    end

    test "transaction state is reset after a disconnect" do
      skip "in-memory db doesn't allow disconnect" if in_memory_db?

      @connection.begin_transaction
      assert @connection.transaction_open?
      @connection.disconnect!
      assert !@connection.transaction_open?
    end
  end
end
