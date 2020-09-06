# frozen_string_literal: true

class AddExpressions < ActiveRecord::Migration::Current
  def self.up
    create_table('expressions') do |t|
      t.column :expression, :string
    end
  end

  def self.down
    drop_table 'expressions'
  end
end
