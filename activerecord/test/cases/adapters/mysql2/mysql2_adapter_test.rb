require "cases/helper"
require "support/ddl_helper"

class Mysql2AdapterTest < ActiveRecord::Mysql2TestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_exec_query_nothing_raises_with_no_result_queries
    assert_nothing_raised do
      with_example_table do
        @conn.exec_query("INSERT INTO ex (number) VALUES (1)")
        @conn.exec_query("DELETE FROM ex WHERE number = 1")
      end
    end
  end

  def test_columns_for_distinct_zero_orders
    assert_equal "posts.id",
      @conn.columns_for_distinct("posts.id", [])
  end

  def test_columns_for_distinct_one_order
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc"])
  end

  def test_columns_for_distinct_few_orders
    assert_equal "posts.id, posts.created_at AS alias_0, posts.position AS alias_1",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
  end

  def test_columns_for_distinct_with_case
    assert_equal(
      "posts.id, CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END AS alias_0",
      @conn.columns_for_distinct("posts.id",
        ["CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END"])
    )
  end

  def test_columns_for_distinct_blank_not_nil_orders
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "", "   "])
  end

  def test_columns_for_distinct_with_arel_order
    order = Object.new
    def order.to_sql
      "posts.created_at desc"
    end
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", [order])
  end

  def test_errors_for_bigint_fks_on_integer_pk_table_in_alter_table
    # table old_cars has primary key of integer

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.add_reference :engines, :old_car
      @conn.add_foreign_key :engines, :old_cars
    end

    assert_includes error.message, <<-MSG.squish
      Column `old_car_id` on table `engines` does not match column `id` on `old_cars`,
      which has type `int(11)`. To resolve this issue, change the type of the `old_car_id`
      column on `engines` to be :integer. (For example `t.integer :old_car_id`).
    MSG
    assert_not_nil error.cause
  ensure
    @conn.execute("ALTER TABLE engines DROP COLUMN old_car_id") rescue nil
  end

  def test_errors_for_bigint_fks_on_integer_pk_table_in_create_table
    # table old_cars has primary key of integer

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<-SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          old_car_id bigint,
          INDEX index_foos_on_old_car_id (old_car_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (old_car_id) REFERENCES old_cars (id)
        )
      SQL
    end

    assert_includes error.message, <<-MSG.squish
      Column `old_car_id` on table `foos` does not match column `id` on `old_cars`,
      which has type `int(11)`. To resolve this issue, change the type of the `old_car_id`
      column on `foos` to be :integer. (For example `t.integer :old_car_id`).
    MSG
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  def test_errors_for_integer_fks_on_bigint_pk_table_in_create_table
    # table old_cars has primary key of bigint

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<-SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          car_id int,
          INDEX index_foos_on_car_id (car_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (car_id) REFERENCES cars (id)
        )
      SQL
    end

    assert_includes error.message, <<-MSG.squish
      Column `car_id` on table `foos` does not match column `id` on `cars`,
      which has type `bigint(20)`. To resolve this issue, change the type of the `car_id`
      column on `foos` to be :bigint. (For example `t.bigint :car_id`).
    MSG
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  def test_errors_for_bigint_fks_on_string_pk_table_in_create_table
    # table old_cars has primary key of string

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.execute(<<-SQL)
        CREATE TABLE activerecord_unittest.foos (
          id bigint NOT NULL AUTO_INCREMENT PRIMARY KEY,
          subscriber_id bigint,
          INDEX index_foos_on_subscriber_id (subscriber_id),
          CONSTRAINT fk_rails_ff771f3c96 FOREIGN KEY (subscriber_id) REFERENCES subscribers (nick)
        )
      SQL
    end

    assert_includes error.message, <<-MSG.squish
      Column `subscriber_id` on table `foos` does not match column `nick` on `subscribers`,
      which has type `varchar(255)`. To resolve this issue, change the type of the `subscriber_id`
      column on `foos` to be :string. (For example `t.string :subscriber_id`).
    MSG
    assert_not_nil error.cause
  ensure
    @conn.drop_table :foos, if_exists: true
  end

  private

    def with_example_table(definition = "id int auto_increment primary key, number int, data varchar(255)", &block)
      super(@conn, "ex", definition, &block)
    end
end
