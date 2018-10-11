# frozen_string_literal: true

require "cases/helper"

class PostgresqlActiveSchemaTest < ActiveRecord::PostgreSQLTestCase
  def setup
    ActiveRecord::Base.connection.materialize_transactions

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      def execute(sql, name = nil) sql end
    end
  end

  teardown do
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      remove_method :execute
    end
  end

  def test_create_database_with_encoding
    assert_equal %(CREATE DATABASE "matt" ENCODING = 'utf8'), create_database(:matt)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, encoding: :latin1)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, "encoding" => :latin1)
  end

  def test_create_database_with_collation_and_ctype
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'UTF8' LC_COLLATE = 'ja_JP.UTF8' LC_CTYPE = 'ja_JP.UTF8'), create_database(:aimonetti, encoding: :"UTF8", collation: :"ja_JP.UTF8", ctype: :"ja_JP.UTF8")
  end

  def test_add_index
    # add_index calls index_name_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) { |*| false }

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people"  ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, unique: true, where: "state = 'active'")

    expected = %(CREATE UNIQUE INDEX  "index_people_on_lower_last_name" ON "people"  (lower(last_name)))
    assert_equal expected, add_index(:people, "lower(last_name)", unique: true)

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name_varchar_pattern_ops" ON "people"  (last_name varchar_pattern_ops))
    assert_equal expected, add_index(:people, "last_name varchar_pattern_ops", unique: true)

    expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people"  ("last_name"))
    assert_equal expected, add_index(:people, :last_name, algorithm: :concurrently)

    expected = %(CREATE  INDEX  "index_people_on_last_name_and_first_name" ON "people"  ("last_name" DESC, "first_name" ASC))
    assert_equal expected, add_index(:people, [:last_name, :first_name], order: { last_name: :desc, first_name: :asc })
    assert_equal expected, add_index(:people, ["last_name", :first_name], order: { last_name: :desc, "first_name" => :asc })

    %w(gin gist hash btree).each do |type|
      expected = %(CREATE  INDEX  "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, using: type)

      expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, using: type, algorithm: :concurrently)

      expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people" USING #{type} ("last_name") WHERE state = 'active')
      assert_equal expected, add_index(:people, :last_name, using: type, unique: true, where: "state = 'active'")

      expected = %(CREATE UNIQUE INDEX  "index_people_on_lower_last_name" ON "people" USING #{type} (lower(last_name)))
      assert_equal expected, add_index(:people, "lower(last_name)", using: type, unique: true)
    end

    expected = %(CREATE  INDEX  "index_people_on_last_name" ON "people" USING gist ("last_name" bpchar_pattern_ops))
    assert_equal expected, add_index(:people, :last_name, using: :gist, opclass: { last_name: :bpchar_pattern_ops })

    expected = %(CREATE  INDEX  "index_people_on_last_name_and_first_name" ON "people"  ("last_name" DESC NULLS LAST, "first_name" ASC))
    assert_equal expected, add_index(:people, [:last_name, :first_name], order: { last_name: "DESC NULLS LAST", first_name: :asc })

    expected = %(CREATE  INDEX  "index_people_on_last_name" ON "people"  ("last_name" NULLS FIRST))
    assert_equal expected, add_index(:people, :last_name, order: "NULLS FIRST")

    assert_raise ArgumentError do
      add_index(:people, :last_name, algorithm: :copy)
    end

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :remove_method, :index_name_exists?
  end

  def test_remove_index
    # remove_index calls index_name_for_remove which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_for_remove) do |*|
      "index_people_on_last_name"
    end

    expected = %(DROP INDEX CONCURRENTLY "index_people_on_last_name")
    assert_equal expected, remove_index(:people, name: "index_people_on_last_name", algorithm: :concurrently)

    assert_raise ArgumentError do
      add_index(:people, :last_name, algorithm: :copy)
    end

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :remove_method, :index_name_for_remove
  end

  def test_remove_index_when_name_is_specified
    expected = %(DROP INDEX CONCURRENTLY "index_people_on_last_name")
    assert_equal expected, remove_index(:people, name: "index_people_on_last_name", algorithm: :concurrently)
  end

  def test_remove_index_with_wrong_option
    assert_raises ArgumentError do
      remove_index(:people, coulmn: :last_name)
    end
  end

  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end
