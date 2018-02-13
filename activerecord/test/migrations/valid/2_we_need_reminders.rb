# frozen_string_literal: true

class WeNeedReminders < ActiveRecord::Migration::Current
  def self.up
    create_table("reminders") do |t|
      t.column :content, :text
      t.column :remind_at, :datetime
    end
  end

  def self.down
    drop_table "reminders"
  end
end
