class WeNeedReminders < ActiveRecord::Migration
  def self.up
    create_table :reminders do
      text :content
      datetime :remind_at
    end
  end

  def self.down
    drop_table "reminders"
  end
end
