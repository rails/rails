module ARTest
  module Migration
    def self.with_migrations_path(path)
      old_path = ActiveRecord::Migrator.migrations_paths
      ActiveRecord::Migrator.migrations_paths = path
      yield
    ensure
      ActiveRecord::Migrator.migrations_paths = old_path
    end
  end
end

