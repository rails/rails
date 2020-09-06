# frozen_string_literal: true

require 'cases/helper'
require 'support/connection_helper'

class PostgresqlEnumTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper

  class PostgresqlEnum < ActiveRecord::Base
    self.table_name = 'postgresql_enums'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.execute <<~SQL
        CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      SQL
      @connection.create_table('postgresql_enums') do |t|
        t.column :current_mood, :mood
      end
    end
  end

  teardown do
    @connection.drop_table 'postgresql_enums', if_exists: true
    @connection.execute 'DROP TYPE IF EXISTS mood'
    reset_connection
  end

  def test_column
    column = PostgresqlEnum.columns_hash['current_mood']
    assert_equal :enum, column.type
    assert_equal 'mood', column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlEnum.type_for_attribute('current_mood')
    assert_not_predicate type, :binary?
  end

  def test_enum_defaults
    @connection.add_column 'postgresql_enums', 'good_mood', :mood, default: 'happy'
    PostgresqlEnum.reset_column_information

    assert_equal 'happy', PostgresqlEnum.column_defaults['good_mood']
    assert_equal 'happy', PostgresqlEnum.new.good_mood
  ensure
    PostgresqlEnum.reset_column_information
  end

  def test_enum_mapping
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    enum = PostgresqlEnum.first
    assert_equal 'sad', enum.current_mood

    enum.current_mood = 'happy'
    enum.save!

    assert_equal 'happy', enum.reload.current_mood
  end

  def test_invalid_enum_update
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    enum = PostgresqlEnum.first
    enum.current_mood = 'angry'

    assert_raise ActiveRecord::StatementInvalid do
      enum.save
    end
  end

  def test_no_oid_warning
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    stderr_output = capture(:stderr) { PostgresqlEnum.first }

    assert_predicate stderr_output, :blank?
  end

  def test_enum_type_cast
    enum = PostgresqlEnum.new
    enum.current_mood = :happy

    assert_equal 'happy', enum.current_mood
  end

  def test_assigning_enum_to_nil
    model = PostgresqlEnum.new(current_mood: nil)

    assert_nil model.current_mood
    assert model.save
    assert_nil model.reload.current_mood
  end
end
