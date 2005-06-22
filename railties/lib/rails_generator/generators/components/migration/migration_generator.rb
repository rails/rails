class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory File.join('db/migrate')
      next_migration_number = Dir.glob("db/migrate/[0-9]*.*").size + 1
      m.template 'migration.rb', File.join('db/migrate', "#{next_migration_number}_#{file_name}.rb")
    end
  end
end
