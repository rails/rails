# frozen_string_literal: true

class MysqlOnly < ActiveRecord::Migration::Current
  def self.change
    create_table "mysql_only"
  end
end
