require 'cases/helper'

class PostgresqlActiveSchemaTest < ActiveRecord::TestCase
  def setup
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      def execute(sql, name = nil) sql end
    end
  end

  def teardown
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      remove_method :execute
    end
  end

  def test_create_database_with_encoding
    assert_equal %(CREATE DATABASE "matt" ENCODING = 'utf8'), create_database(:matt)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, :encoding => :latin1)
  end

  def test_create_database_with_collation_and_ctype
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'UTF8' LC_COLLATE = 'ja_JP.UTF8' LC_CTYPE = 'ja_JP.UTF8'), create_database(:aimonetti, :encoding => :"UTF8", :collation => :"ja_JP.UTF8", :ctype => :"ja_JP.UTF8")
  end

  def test_add_index
    # add_index calls index_name_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) do |*|
      false
    end

    expected = %(CREATE UNIQUE INDEX "index_people_on_last_name" ON "people" ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'")

    %w(gin gist hash btree).each do |type|
      expected = %(CREATE  INDEX "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, :type => type)
    end

    expected = %(CREATE UNIQUE INDEX "index_people_on_last_name" ON "people" USING gist ("last_name"))
    assert_equal expected, add_index(:people, :last_name, :unique => true, :type => :gist)

    expected = %(CREATE UNIQUE INDEX "index_people_on_last_name" ON "people" USING gist ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'", :type => :gist)

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:remove_method, :index_name_exists?)
  end

  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end
