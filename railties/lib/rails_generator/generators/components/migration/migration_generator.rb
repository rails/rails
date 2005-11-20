class MigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate'
    end
  end
end
