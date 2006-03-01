# clear
task :clear_logs => "log:clear"

# test
task :recent          => "test:recent"
task :test_units      => "test:units"
task :test_functional => "test:functionals"
task :test_plugins    => "test:plugins"


# doc
task :appdoc            => "doc:app"
task :apidoc            => "doc:rails"
task :plugindoc         => "doc:plugins"
task :clobber_plugindoc => "doc:clobber_plugins"

FileList['vendor/plugins/**'].collect { |plugin| File.basename(plugin) }.each do |plugin|
  task :"#{plugin}_plugindoc" => "doc:plugins:#{plugin}"
end


# rails
task :freeze_gems        => "rails:freeze:gems"
task :freeze_edge        => "rails:freeze:edge"
task :unfreeze_rails     => "rails:unfreeze"
task :add_new_scripts    => "rails:update:scripts"
task :update_javascripts => "rails:update:javascripts"


# db
task :migrate                 => "db:migrate"
task :load_fixtures           => "db:fixtures:load"

task :db_schema_dump          => "db:schema:dump"
task :db_schema_import        => "db:schema:load"

task :db_structure_dump       => "db:structure:dump"

task :purge_test_database     => "db:test:purge"
task :clone_schema_to_test    => "db:test:clone"
task :clone_structure_to_test => "db:test:clone_structure"
task :prepare_test_database   => "db:test:prepare"

task :create_sessions_table   => "db:sessions:create"
task :drop_sessions_table     => "db:sessions:drop"
task :purge_sessions_table    => "db:sessions:recreate"
