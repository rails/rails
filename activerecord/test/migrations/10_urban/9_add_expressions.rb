class AddExpressions < ActiveRecord::Migration.version("#{::ActiveRecord::Migration.current_version}")
  def self.up
    create_table("expressions") do |t|
      t.column :expression, :string
    end
  end

  def self.down
    drop_table "expressions"
  end
end
