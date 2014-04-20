# -*- coding: utf-8 -*-
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlCompositeTest < ActiveRecord::TestCase
  class PostgresqlComposite < ActiveRecord::Base
    self.table_name = "postgresql_composites"
  end

  teardown do
    @connection.execute 'DROP TABLE IF EXISTS postgresql_composites'
    @connection.execute 'DROP TYPE IF EXISTS full_address'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.execute <<-SQL
         CREATE TYPE full_address AS
         (
             city VARCHAR(90),
             street VARCHAR(90)
         );
        SQL
      @connection.create_table('postgresql_composites') do |t|
        t.column :address, :full_address
      end
    end
  end

  def test_column
    column = PostgresqlComposite.columns_hash["address"]
    # TODO: Composite columns should have a type
    assert_nil column.type
    assert_equal "full_address", column.sql_type
    assert_not column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end

  def test_composite_mapping
    @connection.execute "INSERT INTO postgresql_composites VALUES (1, ROW('Paris', 'Champs-Élysées'));"
    composite = PostgresqlComposite.first
    assert_equal "(Paris,Champs-Élysées)", composite.address

    composite.address = "(Paris,Rue Basse)"
    composite.save!

    assert_equal '(Paris,"Rue Basse")', composite.reload.address
  end
end
