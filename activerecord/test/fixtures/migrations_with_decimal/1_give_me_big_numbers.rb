class GiveMeBigNumbers < ActiveRecord::Migration
  def self.up
    create_table :big_numbers do |table|
      table.column :bank_balance, :decimal, :precision => 10, :scale => 2
      table.column :big_bank_balance, :decimal, :precision => 15, :scale => 2
      table.column :world_population, :decimal, :precision => 10
      table.column :my_house_population, :decimal, :precision => 2
      table.column :value_of_e, :decimal
    end
  end

  def self.down
    drop_table :big_numbers
  end
end
