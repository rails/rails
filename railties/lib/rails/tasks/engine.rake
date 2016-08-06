task "load_app" do
  namespace :app do
    load APP_RAKEFILE
  end
  task :environment => "app:environment"

  if !defined?(ENGINE_ROOT) || !ENGINE_ROOT
    ENGINE_ROOT = find_engine_path(APP_RAKEFILE)
  end
end

def app_task(name)
  task name => [:load_app, "app:db:#{name}"]
end

namespace :db do
  app_task "reset"

  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  app_task "migrate"
  app_task "migrate:up"
  app_task "migrate:down"
  app_task "migrate:redo"
  app_task "migrate:reset"

  desc "Display status of migrations"
  app_task "migrate:status"

  desc "Create the database from config/database.yml for the current Rails.env (use db:create:all to create all databases in the config)"
  app_task "create"
  app_task "create:all"

  desc "Drops the database for the current Rails.env (use db:drop:all to drop all databases)"
  app_task "drop"
  app_task "drop:all"

  desc "Load fixtures into the current environment's database."
  app_task "fixtures:load"

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  app_task "rollback"

  desc "Create a db/schema.rb file that can be portably used against any DB supported by Active Record"
  app_task "schema:dump"

  desc "Load a schema.rb file into the database"
  app_task "schema:load"

  desc "Load the seed data from db/seeds.rb"
  app_task "seed"

  desc "Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)"
  app_task "setup"

  desc "Dump the database structure to an SQL file"
  app_task "structure:dump"

  desc "Retrieves the current schema version number"
  app_task "version"
end

def find_engine_path(path)
  return File.expand_path(Dir.pwd) if path == "/"

  if Rails::Engine.find(path)
    path
  else
    find_engine_path(File.expand_path("..", path))
  end
end

Rake.application.invoke_task(:load_app)
