# encoding: utf-8

require "cases/helper"
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
      return skip "do not test on PG without citext"
    end

    @connection.transaction do
      @connection.create_table('citexts') do |t|
        t.citext 'cival'
      end
    end
    @column = Citext.columns.find { |c| c.name == 'cival' }
  end

  def teardown
    @connection.execute 'drop table if exists citexts'
  end

  def test_citext_enabled
    assert @connection.extension_enabled?('citext')
  end

  def test_disable_citext
    if @connection.extension_enabled?('citext')
      @connection.disable_extension 'citext'
      assert_not @connection.extension_enabled?('citext')
    end
  end

  def test_enable_citext
    if @connection.extension_enabled?('citext')
      @connection.disable_extension 'citext'
    end

    assert_not @connection.extension_enabled?('citext')
    @connection.enable_extension 'citext'
    assert @connection.extension_enabled?('citext')
  end

  def test_column
    assert_equal :string, @column.type
  end

  def test_write
    x = Citext.new(cival: 'Some CI Text')
    assert x.save!
  end

  def test_select_case_insensitive
    @connection.execute "insert into citexts (cival) values('Cased Text')"
    x = Citext.where(cival: 'cased text').first
    assert_equal('Cased Text', x.cival)
  end
end

