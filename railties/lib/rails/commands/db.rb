module Rails
  module Commands
    class Db < Command
      set_banner :db_create,  
        'Creates the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:create:all to create all databases in the config)'
      set_banner :db_drop,    
        'Drops the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databases in the config)'
      set_banner :db_fixtures_load, 
        'Loads fixtures into the current environment\'s database'
      set_banner :db_migrate, 
        'Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)'
      set_banner :db_migrate_status, 
        'Display status of migrations'
      set_banner :db_rollback, 
        'Rolls the schema back to the previous version (specify steps w/ STEP=n)'
      set_banner :db_schema_cache_clear, 
        'Clears a db/schema_cache.dump file'
      set_banner :db_schema_cache_dump, 
        'Creates a db/schema_cache.dump file'
      set_banner :db_schema_dump, 
        'Creates a db/schema.rb file that is portable against any DB supported by Active Record'
      set_banner :db_schema_load, 
        'Loads a schema.rb file into the database'
      set_banner :db_seed, 
        'Loads the seed data from db/seeds.rb'
      set_banner :db_setup,
        'Creates the database, loads the schema, and initializes with the seed data (use db_reset to also drop the database first)'
      set_banner :db_structure_dump, 
        'Dumps the database structure to db/structure.sql'
      set_banner :db_structure_load, 
        'Recreates the databases from the structure.sql file'
      set_banner :db_version, 
        'Retrieves the current schema version number'

      rake_delegate 'db:create', 'db:drop', 'db:fixtures:load', 'db:migrate', 
        'db:migrate:status', 'db:rollback', 'db:schema:cache:clear',
        'db:schema:cache:dump', 'db:schema:dump', 'db:schema:load', 'db:seed',
        'db:setup', 'db:structure:dump', 'db:structure:load', 'db:version'
    end
  end
end
