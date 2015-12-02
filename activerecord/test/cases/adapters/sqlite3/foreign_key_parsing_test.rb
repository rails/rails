require "cases/helper"

class SQLite3ForeignKeyParsingTest < ActiveRecord::SQLite3TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table :parsing_table_sqlite3, if_exists: true
  end

  test "nameless foreign keys defined as column constraints" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text REFERENCES authors(name), author_id int REFERENCES authors(id))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.each {|fk| assert_equal("authors", fk.to_table)}
    keys.sort_by! {|fk| fk.column}

    fk = keys.first
    assert_equal nil, fk.name
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal nil, fk.name
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key
  end

  test "nameless foreign keys defined as table constraints" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text, author_id int, FOREIGN KEY (author_name) REFERENCES authors(name), FOREIGN KEY (author_id) REFERENCES authors(id))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.each {|fk| assert_equal("authors", fk.to_table)}
    keys.sort_by! {|fk| fk.column}

    fk = keys.first
    assert_equal nil, fk.name
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal nil, fk.name
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key
  end

  test "named foreign keys defined as column constraints" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text CONSTRAINT foo REFERENCES authors(name), author_id int CONSTRAINT bar REFERENCES authors(id))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.each {|fk| assert_equal("authors", fk.to_table)}
    keys.sort_by! {|fk| fk.column}

    fk = keys.first
    assert_equal "bar", fk.name
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal "foo", fk.name
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key
  end

  test "named foreign keys defined as table constraints" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text, author_id int, CONSTRAINT foo FOREIGN KEY (author_name) REFERENCES authors(name), CONSTRAINT bar FOREIGN KEY (author_id) REFERENCES authors(id))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.each {|fk| assert_equal("authors", fk.to_table)}
    keys.sort_by! {|fk| fk.column}

    fk = keys.first
    assert_equal "bar", fk.name
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal "foo", fk.name
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key
  end

  test "foreign keys defined in both table and column constraints" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text, author_id int REFERENCES authors(id), CONSTRAINT foo FOREIGN KEY (author_name) REFERENCES authors(name))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.each {|fk| assert_equal("authors", fk.to_table)}
    keys.sort_by! {|fk| fk.column}

    fk = keys.first
    assert_equal nil, fk.name
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal "foo", fk.name
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key
  end

  test "mixed foreign keys and collation setting on one column" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text CONSTRAINT foo REFERENCES authors(name) COLLATE RTRIM REFERENCES people(name))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.sort_by! {|fk| fk.to_table}

    fk = keys.first
    assert_equal "foo", fk.name
    assert_equal "authors", fk.to_table
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key

    fk = keys.second
    assert_equal nil, fk.name
    assert_equal "people", fk.to_table
    assert_equal "author_name", fk.column
    assert_equal "name", fk.primary_key

    column = @connection.columns(:parsing_table_sqlite3).find { |c| c.name == 'author_name' }
    assert_equal 'RTRIM', column.collation
  end

  test "foreign keys with implicit target column" do
    sql = "CREATE TABLE parsing_table_sqlite3 (author_name text, author_id int REFERENCES authors, CONSTRAINT foo FOREIGN KEY (author_id) REFERENCES people)"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 2, keys.size
    keys.sort_by! {|fk| fk.to_table}

    fk = keys.first
    assert_equal nil, fk.name
    assert_equal "authors", fk.to_table
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key

    fk = keys.second
    assert_equal "foo", fk.name
    assert_equal "people", fk.to_table
    assert_equal "author_id", fk.column
    assert_equal "id", fk.primary_key
  end

  test "foreign keys with escaped column names and escaped constraint names" do
    sql = "CREATE TABLE parsing_table_sqlite3 (')author,''name''' text CONSTRAINT 'foo,''bar' REFERENCES authors(name))"
    @connection.execute(sql)

    keys = @connection.foreign_keys(:parsing_table_sqlite3)
    assert_equal 1, keys.size

    fk = keys.first
    assert_equal "foo,'bar", fk.name
    assert_equal ")author,'name'", fk.column
    assert_equal "name", fk.primary_key
  end
end
