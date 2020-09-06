# frozen_string_literal: true

class MigrationVersionCheck < ActiveRecord::Migration::Current
  def self.up
    raise 'incorrect migration version' unless version == 20131219224947
  end

  def self.down
  end
end
