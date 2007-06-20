require 'abstract_unit'

class AdapterTest < Test::Unit::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_tables
    if @connection.respond_to?(:tables)
      tables = @connection.tables
      assert tables.include?("accounts")
      assert tables.include?("authors")
      assert tables.include?("tasks")
      assert tables.include?("topics")
    else
      warn "#{@connection.class} does not respond to #tables"
    end
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
      assert_equal ENV['ARUNIT_DB_NAME'] || "activerecord_unittest", @connection.current_database
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
      alias_method :table_alias_length, :old_table_alias_length
    end
  end

  # test resetting sequences in odd tables in postgreSQL
  if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
    require 'fixtures/movie'
    require 'fixtures/subscriber'

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

end
