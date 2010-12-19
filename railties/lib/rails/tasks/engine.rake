task "load_app" do
  namespace :app do
    load APP_RAKEFILE
  end

  if !defined?(ENGINE_PATH) || !ENGINE_PATH
    ENGINE_PATH = find_engine_path(APP_RAKEFILE)
  end
end

namespace :db do
  task :reset     => [:load_app, :"app:db:reset"]

  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  task :migrate         => [:load_app, :"app:db:migrate"]
  task :"migrate:up"    => [:load_app, :"app:db:migrate:up"]
  task :"migrate:down"  => [:load_app, :"app:db:migrate:down"]
  task :"migrate:redo"  => [:load_app, :"app:db:migrate:redo"]
  task :"migrate:reset" => [:load_app, :"app:db:migrate:reset"]

  desc "Display status of migrations"
  task :"migrate:status" => [:load_app, :"app:db:migrate:status"]

  desc 'Create the database from config/database.yml for the current Rails.env (use db:create:all to create all dbs in the config)'
  task :create        => [:load_app, :"app:db:create"]
  task :"create:all"  => [:load_app, :"app:db:create:all"]

  desc 'Drops the database for the current Rails.env (use db:drop:all to drop all databases)'
  task :drop        => [:load_app, :"app:db:drop"]
  task :"drop:all"  => [:load_app, :"app:db:drop:all"]

  desc "Load fixtures into the current environment's database."
  task :"fixtures:load" => [:load_app, :"app:db:fixtures:load"]

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  task :rollback => [:load_app, :"app:db:rollback"]

  desc "Create a db/schema.rb file that can be portably used against any DB supported by AR"
  task :"schema:dump" => [:load_app, :"app:db:schema:dump"]

  desc "Load a schema.rb file into the database"
  task :"schema:load" => [:load_app, :"app:db:schema:load"]

  desc "Load the seed data from db/seeds.rb"
  task :seed => [:load_app, :"app:db:seed"]

  desc "Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)"
  task :setup => [:load_app, :"app:db:setup"]

  desc "Dump the database structure to an SQL file"
  task :"structure:dump" => [:load_app, :"app:db:structure:dump"]

  desc "Retrieves the current schema version number"
  task :version => [:load_app, :"app:db:version"]
end


def find_engine_path(path)
  return if path == "/"

  if Rails::Engine.find(path)
    path
  else
    find_engine_path(File.expand_path('..', path))
  end
end
