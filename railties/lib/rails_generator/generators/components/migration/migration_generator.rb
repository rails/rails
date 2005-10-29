class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory 'db/migrate'
      m.migration_template 'migration.rb', 'db/migrate'
    end
  end

  protected
    def existing_migrations(file_name)
      Dir.glob("db/migrate/[0-9]*_#{file_name}.rb")
    end

    def migration_exists?(file_name)
      not existing_migrations(file_name).empty?
    end

    def current_migration_number
      Dir.glob('db/migrate/[0-9]*.rb').inject(0) do |max, file_path|
        n = File.basename(file_path).split('_', 2).first.to_i
        if n > max then n else max end
      end
    end

    def next_migration_number
      current_migration_number + 1
    end

    def next_migration_string(padding = 3)
      "%.#{padding}d" % next_migration_number
    end
end

module Rails::Generator::Commands
  # When creating, it knows to find the first available file in db/migrate and use the migration.rb template.
  class Create
    def migration_template(relative_source, relative_destination, template_options = {})
      raise "Another migration is already named #{file_name}: #{existing_migrations(file_name).first}" if migration_exists?(file_name)
      template(relative_source, "#{relative_destination}/#{next_migration_string}_#{file_name}.rb", template_options)
    end
  end

  # When deleting, it knows to delete every file named "[0-9]*_#{file_name}".
  class Destroy
    def migration_template(relative_source, relative_destination, template_options = {})
      raise "There is no migration named #{file_name}" unless migration_exists?(file_name)
      existing_migrations(file_name).each do |file_path|
        file(relative_source, file_path, template_options)
      end
    end
  end

  class List
    def migration_template(relative_source, relative_destination, options = {})
      logger.migration_template file_name
    end
  end
end
