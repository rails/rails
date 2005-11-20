class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.directory 'db/migrate'
      m.migration_template 'migration.rb', 'db/migrate'
    end
  end
end
