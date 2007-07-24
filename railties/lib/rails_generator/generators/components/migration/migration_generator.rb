class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate'
    end
  end

  def auto_migration direction
    case class_name.underscore
    when /^(add|remove)_(.*)_(?:to|from)_(.*)/ then
      action, col, tbl = $1, $2, $3.pluralize

      unless (action == "add") ^ (direction == :up) then
        %(\n    add_column :#{tbl}, :#{col}, :type, :null => :no?, :default => :maybe?)
      else
        %(\n    remove_column :#{tbl}, :#{col})
      end
    end
  end
end
