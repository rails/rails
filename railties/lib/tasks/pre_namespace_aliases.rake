def deprecated_task(name, new_name)
  task name=>new_name do 
    $stderr.puts "The rake task #{name} has been deprecated, please use the replacement version #{new_name}"
  end
end


# clear
deprecated_task :clear_logs, "log:clear"

# test
deprecated_task :recent,          "test:recent"
deprecated_task :test_units,      "test:units"
deprecated_task :test_functional, "test:functionals"
deprecated_task :test_plugins,    "test:plugins"


# doc
deprecated_task :appdoc,            "doc:app"
deprecated_task :apidoc,            "doc:rails"
deprecated_task :plugindoc,         "doc:plugins"
deprecated_task :clobber_plugindoc, "doc:clobber_plugins"

FileList['vendor/plugins/**'].collect { |plugin| File.basename(plugin) }.each do |plugin|
  deprecated_task :"#{plugin}_plugindoc", "doc:plugins:#{plugin}"
end


# rails
deprecated_task :freeze_gems,        "rails:freeze:gems"
deprecated_task :freeze_edge,        "rails:freeze:edge"
deprecated_task :unfreeze_rails,     "rails:unfreeze"
deprecated_task :add_new_scripts,    "rails:update:scripts"
deprecated_task :update_javascripts, "rails:update:javascripts"


# db
deprecated_task :migrate,       "db:migrate"
deprecated_task :load_fixtures, "db:fixtures:load"

deprecated_task :db_schema_dump,   "db:schema:dump"
deprecated_task :db_schema_import, "db:schema:load"

deprecated_task :db_structure_dump, "db:structure:dump"

deprecated_task :purge_test_database,     "db:test:purge"
deprecated_task :clone_schema_to_test,    "db:test:clone"
deprecated_task :clone_structure_to_test, "db:test:clone_structure"
deprecated_task :prepare_test_database,   "db:test:prepare"

deprecated_task :create_sessions_table, "db:sessions:create"
deprecated_task :drop_sessions_table,   "db:sessions:drop"
deprecated_task :purge_sessions_table,  "db:sessions:recreate"
