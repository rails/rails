# -*- coding: utf-8 -*-
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlEnumTest < ActiveRecord::TestCase
  class PostgresqlEnum < ActiveRecord::Base
    self.table_name = "postgresql_enums"
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS postgresql_enums'
    @connection.execute 'DROP TYPE IF EXISTS mood'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.execute <<-SQL
        CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      SQL
      @connection.create_table('postgresql_enums') do |t|
        t.column :current_mood, :mood
      end
    end
    # reload type map after creating the enum type
    @connection.send(:reload_type_map)
  end

  def test_enum_mapping
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    enum = PostgresqlEnum.first
    assert_equal "sad", enum.current_mood

    enum.current_mood = "happy"
    enum.save!

    assert_equal "happy", enum.reload.current_mood
  end

  def test_invalid_enum_update
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    enum = PostgresqlEnum.first
    enum.current_mood = "angry"

    assert_raise ActiveRecord::StatementInvalid do
      enum.save
    end
  end

  def test_no_oid_warning
    @connection.execute "INSERT INTO postgresql_enums VALUES (1, 'sad');"
    stderr_output = capture(:stderr) { PostgresqlEnum.first }

    assert stderr_output.blank?
  end

  def test_enum_type_cast
    enum = PostgresqlEnum.new
    enum.current_mood = :happy

    assert_equal "happy", enum.current_mood
  end
end
