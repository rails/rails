class <%= migration_class_name %> < ActiveRecord::Migration
  def change
    <%= migration_action %>_timestamps :<%= table_name %>
  end
end
