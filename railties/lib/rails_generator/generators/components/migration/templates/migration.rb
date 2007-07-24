class <%= class_name.underscore.camelize %> < ActiveRecord::Migration
  def self.up<%= auto_migration :up %>
  end

  def self.down<%= auto_migration :down %>
  end
end
