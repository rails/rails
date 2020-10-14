# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

class Mysql2AdapterTest < ActiveRecord::Mysql2TestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.connection
    @connection_handler = ActiveRecord::Base.connection_handler
  end

  def test_connection_error
    assert_raises ActiveRecord::ConnectionNotEstablished do
      ActiveRecord::Base.mysql2_connection(socket: File::NULL)
    end
  end

  def test_reconnection_error
    fake_connection = Class.new do
      def query_options
        {}
      end

      def query(*)
      end

      def close
      end
    end.new
    @conn = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(
      fake_connection,
      ActiveRecord::Base.logger,
      nil,
      { socket: File::NULL }
    )
    assert_raises ActiveRecord::ConnectionNotEstablished do
      @conn.reconnect!
    end
  end

  def test_exec_query_nothing_raises_with_no_result_queries
    assert_nothing_raised do
      with_example_table do
        @conn.exec_query("INSERT INTO ex (number) VALUES (1)")
        @conn.exec_query("DELETE FROM ex WHERE number = 1")
      end
    end
  end

  def test_database_exists_returns_false_if_database_does_not_exist
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
    config = db_config.configuration_hash.merge(database: "inexistent_activerecord_unittest")
    assert_not ActiveRecord::ConnectionAdapters::Mysql2Adapter.database_exists?(config),
      "expected database to not exist"
  end

  def test_database_exists_returns_true_when_the_database_exists
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
    assert ActiveRecord::ConnectionAdapters::Mysql2Adapter.database_exists?(db_config.configuration_hash),
      "expected database #{db_config.database} to exist"
  end

  def test_columns_for_distinct_zero_orders
    assert_equal "posts.id",
      @conn.columns_for_distinct("posts.id", [])
  end

  def test_columns_for_distinct_one_order
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc"])
  end

  def test_columns_for_distinct_few_orders
    assert_equal "posts.created_at AS alias_0, posts.position AS alias_1, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
  end

  def test_columns_for_distinct_with_case
    assert_equal(
      "CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id",
        ["CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END"])
    )
  end

  def test_columns_for_distinct_blank_not_nil_orders
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "", "   "])
  end

  def test_columns_for_distinct_with_arel_order
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine

    order = Arel.sql("posts.created_at").desc
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", [order])
  ensure
    Arel::Table.engine = ActiveRecord::Base
  end

  def test_errors_for_bigint_fks_on_integer_pk_table_in_alter_table
    # table old_cars has primary key of integer

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.add_reference :engines, :old_car
      @conn.add_foreign_key :engines, :old_cars
    end

    assert_match(
      %r/Column `old_car_id` on table `engines` does not match column `id` on `old_cars`, which has type `int(\(11\))?`\./,
      error.message
    )
    assert_match(
      %r/To resolve this issue, change the type of the `old_car_id` column on `engines` to be :integer\. \(For example `t.integer :old_car_id`\)\./,
      error.message
    )
    assert_not_nil error.cause
  ensure
    @conn.execute("ALTER TABLE engines DROP COLUMN old_car_id") rescue nil
  end

  def test_errors_for_bigint_fks_on_integer_pk_table_in_create_table
    # table old_cars has primary key of integer

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<~SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          old_car_id bigint,
          INDEX index_foos_on_old_car_id (old_car_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (old_car_id) REFERENCES old_cars (id)
        )
      SQL
    end

    assert_match(
      %r/Column `old_car_id` on table `foos` does not match column `id` on `old_cars`, which has type `int(\(11\))?`\./,
      error.message
    )
    assert_match(
      %r/To resolve this issue, change the type of the `old_car_id` column on `foos` to be :integer\. \(For example `t.integer :old_car_id`\)\./,
      error.message
    )
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  def test_errors_for_integer_fks_on_bigint_pk_table_in_create_table
    # table old_cars has primary key of bigint

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<~SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          car_id int,
          INDEX index_foos_on_car_id (car_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (car_id) REFERENCES cars (id)
        )
      SQL
    end

    assert_match(
      %r/Column `car_id` on table `foos` does not match column `id` on `cars`, which has type `bigint(\(20\))?`\./,
      error.message
    )
    assert_match(
      %r/To resolve this issue, change the type of the `car_id` column on `foos` to be :bigint\. \(For example `t.bigint :car_id`\)\./,
      error.message
    )
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  def test_errors_for_bigint_fks_on_string_pk_table_in_create_table
    # table old_cars has primary key of string

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<~SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          subscriber_id bigint,
          INDEX index_foos_on_subscriber_id (subscriber_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (subscriber_id) REFERENCES subscribers (nick)
        )
      SQL
    end

    assert_includes error.message, <<~MSG.squish
      Column `subscriber_id` on table `foos` does not match column `nick` on `subscribers`,
      which has type `varchar(255)`. To resolve this issue, change the type of the `subscriber_id`
      column on `foos` to be :string. (For example `t.string :subscriber_id`).
    MSG
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  def test_errors_when_an_insert_query_is_called_while_preventing_writes
    assert_raises(ActiveRecord::ReadOnlyError) do
      @connection_handler.while_preventing_writes do
        @conn.insert("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")
      end
    end
  end

  def test_errors_when_an_update_query_is_called_while_preventing_writes
    @conn.insert("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    assert_raises(ActiveRecord::ReadOnlyError) do
      @connection_handler.while_preventing_writes do
        @conn.update("UPDATE `engines` SET `engines`.`car_id` = '9989' WHERE `engines`.`car_id` = '138853948594'")
      end
    end
  end

  def test_errors_when_a_delete_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    assert_raises(ActiveRecord::ReadOnlyError) do
      @connection_handler.while_preventing_writes do
        @conn.execute("DELETE FROM `engines` where `engines`.`car_id` = '138853948594'")
      end
    end
  end

  def test_errors_when_a_replace_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    assert_raises(ActiveRecord::ReadOnlyError) do
      @connection_handler.while_preventing_writes do
        @conn.execute("REPLACE INTO `engines` SET `engines`.`car_id` = '249823948'")
      end
    end
  end

  def test_doesnt_error_when_a_select_query_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    @connection_handler.while_preventing_writes do
      assert_equal 1, @conn.execute("SELECT `engines`.* FROM `engines` WHERE `engines`.`car_id` = '138853948594'").entries.count
    end
  end

  def test_doesnt_error_when_a_show_query_is_called_while_preventing_writes
    @connection_handler.while_preventing_writes do
      assert_equal 2, @conn.execute("SHOW FULL FIELDS FROM `engines`").entries.count
    end
  end

  def test_doesnt_error_when_a_set_query_is_called_while_preventing_writes
    @connection_handler.while_preventing_writes do
      assert_nil @conn.execute("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci")
    end
  end

  def test_doesnt_error_when_a_describe_query_is_called_while_preventing_writes
    @connection_handler.while_preventing_writes do
      assert_equal 2, @conn.execute("DESCRIBE engines").entries.count
    end
  end

  def test_doesnt_error_when_a_desc_query_is_called_while_preventing_writes
    @connection_handler.while_preventing_writes do
      assert_equal 2, @conn.execute("DESC engines").entries.count
    end
  end

  def test_doesnt_error_when_a_read_query_with_leading_chars_is_called_while_preventing_writes
    @conn.execute("INSERT INTO `engines` (`car_id`) VALUES ('138853948594')")

    @connection_handler.while_preventing_writes do
      assert_equal 1, @conn.execute("/*action:index*/(\n( SELECT `engines`.* FROM `engines` WHERE `engines`.`car_id` = '138853948594' ) )").entries.count
    end
  end

  def test_read_timeout_exception
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")

    ActiveRecord::Base.establish_connection(
      db_config.configuration_hash.merge("read_timeout" => 1)
    )

    error = assert_raises(ActiveRecord::AdapterTimeout) do
      ActiveRecord::Base.connection.execute("SELECT SLEEP(2)")
    end
    assert_kind_of ActiveRecord::QueryAborted, error

    assert_equal Mysql2::Error::TimeoutError, error.cause.class
  ensure
    ActiveRecord::Base.establish_connection :arunit
  end

  def test_statement_timeout_error_codes
    raw_conn = @conn.raw_connection
    assert_raises(ActiveRecord::StatementTimeout) do
      raw_conn.stub(:query, ->(_sql) { raise Mysql2::Error.new("fail", 50700, ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::ER_FILSORT_ABORT) }) {
        @conn.execute("SELECT 1")
      }
    end

    assert_raises(ActiveRecord::StatementTimeout) do
      raw_conn.stub(:query, ->(_sql) { raise Mysql2::Error.new("fail", 50700, ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::ER_QUERY_TIMEOUT) }) {
        @conn.execute("SELECT 1")
      }
    end
  end

  def test_doesnt_error_when_a_use_query_is_called_while_preventing_writes
    @connection_handler.while_preventing_writes do
      db_name = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").database
      assert_nil @conn.execute("USE #{db_name}")
    end
  end

  private
    def with_example_table(definition = "id int auto_increment primary key, number int, data varchar(255)", &block)
      super(@conn, "ex", definition, &block)
    end
end
