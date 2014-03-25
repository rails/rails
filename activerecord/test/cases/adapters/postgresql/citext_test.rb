# encoding: utf-8

require 'cases/helper'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlCitextTest < ActiveRecord::TestCase
  class Citext < ActiveRecord::Base
    self.table_name = 'citexts'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.extension_enabled?('citext')
      @connection.enable_extension 'citext'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.create_table('citexts') do |t|
      t.citext 'cival'
    end
    @column = Citext.columns_hash['cival']
  end

  teardown do
    @connection.execute 'DROP TABLE IF EXISTS citexts;'
    @connection.execute 'DROP EXTENSION IF EXISTS citext CASCADE;'
  end

  def test_citext_enabled
    assert @connection.extension_enabled?('citext')
  end

  def test_column_type
    assert_equal :citext, @column.type
  end

  def test_column_sql_type
    assert_equal 'citext', @column.sql_type
  end

  def test_change_table_supports_json
    @connection.transaction do
      @connection.change_table('citexts') do |t|
        t.citext 'username'
      end
      Citext.reset_column_information
      column = Citext.columns.find { |c| c.name == 'username' }
      assert_equal :citext, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    Citext.reset_column_information
  end

  def test_write
    x = Citext.new(cival: 'Some CI Text')
    x.save!
    citext = Citext.first
    assert_equal "Some CI Text", citext.cival

    citext.cival = "Some NEW CI Text"
    citext.save!

    assert_equal "Some NEW CI Text", citext.reload.cival
  end

  def test_select_case_insensitive
    @connection.execute "insert into citexts (cival) values('Cased Text')"
    x = Citext.where(cival: 'cased text').first
    assert_equal 'Cased Text', x.cival
  end
end
