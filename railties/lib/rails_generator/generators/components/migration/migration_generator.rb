class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory File.join('db/migrate')
      existing_migrations = Dir.glob("db/migrate/[0-9]*_#{file_name}.rb")
      raise "Another migration already exists with the same name" unless existing_migrations.empty?
      next_migration_number = Dir.glob("db/migrate/[0-9]*.*").size + 1
      m.template 'migration.rb', File.join('db/migrate', "#{next_migration_number}_#{file_name}.rb")
    end
  end
end
