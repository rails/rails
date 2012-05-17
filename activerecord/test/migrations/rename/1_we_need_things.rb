class WeNeedThings < ActiveRecord::Migration
  def self.up
    create_table("things") do |t|
      t.column :content, :text
    end
  end

  def self.down
    drop_table "things"
  end
end