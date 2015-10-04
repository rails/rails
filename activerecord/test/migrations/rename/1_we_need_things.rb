class WeNeedThings < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    create_table("things") do |t|
      t.column :content, :text
    end
  end

  def self.down
    drop_table "things"
  end
end
