class WeNeedReminders < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
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
