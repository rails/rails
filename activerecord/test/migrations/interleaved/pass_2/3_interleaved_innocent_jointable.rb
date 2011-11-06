class InterleavedInnocentJointable < ActiveRecord::Migration
  def self.up
    create_table :people_reminders, :id => false do
      integer :reminder_id
      integer :person_id
    end
  end

  def self.down
    drop_table "people_reminders"
  end
end
