# frozen_string_literal: true

task "load_app" do
  namespace :app do
    load APP_RAKEFILE

    desc "Update some initially generated files"
    task update: [ "update:bin" ]

    namespace :update do
      require "rails/engine/updater"
      # desc "Adds new executables to the engine bin/ directory"
      task :bin do
        Rails::Engine::Updater.run(:create_bin_files)
      end
    end
  end
  task environment: "app:environment"

  if !defined?(ENGINE_ROOT) || !ENGINE_ROOT
    ENGINE_ROOT = find_engine_path(Pathname.new(APP_RAKEFILE))
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

  desc "Drop the database for the current Rails.env (use db:drop:all to drop all databases)"
  app_task "drop"
  app_task "drop:all"

  desc "Load fixtures into the current environment's database."
  app_task "fixtures:load"

  desc "Roll the schema back to the previous version (specify steps w/ STEP=n)."
  app_task "rollback"

  desc "Create a database schema file (either db/schema.rb or db/structure.sql, depending on `config.active_record.schema_format`)"
  app_task "schema:dump"

  desc "Load a schema.rb file into the database"
  app_task "schema:load"

  desc "Load the seed data from db/seeds.rb"
  app_task "seed"

  desc "Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the database first)"
  app_task "setup"

  desc "Retrieve the current schema version number"
  app_task "version"

  # desc 'Load the test schema'
  app_task "test:prepare"
end

def find_engine_path(path)
  return File.expand_path(Dir.pwd) if path.root?

  if Rails::Engine.find(path)
    path.to_s
  else
    find_engine_path(path.join(".."))
  end
end

Rake.application.invoke_task(:load_app)
