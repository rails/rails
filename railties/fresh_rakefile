require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$VERBOSE = nil

require File.dirname(__FILE__) + '/config/environments/production'
require 'code_statistics'

desc "Run all the tests on a fresh test database"
task :default => [ :clone_production_structure_to_test, :test_units, :test_functional ]

desc "Generate API documentatio, show coding stats"
task :doc => [ :appdoc, :stats ]


desc "Run the unit tests in test/unit"
Rake::TestTask.new("test_units") { |t|
  t.libs << "test"
  t.pattern = 'test/unit/*_test.rb'
  t.verbose = true
}

desc "Run the functional tests in test/functional"
Rake::TestTask.new("test_functional") { |t|
  t.libs << "test"
  t.pattern = 'test/functional/*_test.rb'
  t.verbose = true
}

desc "Generate documentation for the application"
Rake::RDocTask.new("appdoc") { |rdoc|
  rdoc.rdoc_dir = 'doc/app'
  rdoc.title    = "Rails Application Documentation"
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('doc/README_FOR_APP')
  rdoc.rdoc_files.include('app/**/*.rb')
}

desc "Generate documentation for the Rails framework"
Rake::RDocTask.new("apidoc") { |rdoc|
  rdoc.rdoc_dir = 'doc/api'
  rdoc.title    = "Rails Framework Documentation"
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('vendor/railties/CHANGELOG')
  rdoc.rdoc_files.include('vendor/railties/MIT-LICENSE')
  rdoc.rdoc_files.include('vendor/activerecord/README')
  rdoc.rdoc_files.include('vendor/activerecord/CHANGELOG')
  rdoc.rdoc_files.include('vendor/activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('vendor/activerecord/lib/active_record/vendor/*')
  rdoc.rdoc_files.include('vendor/actionpack/README')
  rdoc.rdoc_files.include('vendor/actionpack/CHANGELOG')
  rdoc.rdoc_files.include('vendor/actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('vendor/actionpack/lib/action_view/**/*.rb')
}

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  CodeStatistics.new(
    ["Controllers", "app/controllers"], 
    ["Helpers", "app/helpers"], 
    ["Models", "app/models"],
    ["Units", "test/unit"],
    ["Functionals", "test/functional"]
  ).to_s
end

desc "Recreate the test databases from the production structure"
task :clone_production_structure_to_test => [ :db_structure_dump, :purge_test_database ] do
  if database_configurations["test"]["adapter"] == "mysql"
    ActiveRecord::Base.establish_connection(database_configurations["test"])
    ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
    IO.readlines("db/production_structure.sql").join.split("\n\n").each do |table|
      ActiveRecord::Base.connection.execute(table)
    end
  elsif database_configurations["test"]["adapter"] == "postgresql"
    `psql -U #{database_configurations["test"]["username"]} -f db/production_structure.sql #{database_configurations["test"]["database"]}`
  end
end

desc "Dump the database structure to a SQL file"
task :db_structure_dump do
  if database_configurations["test"]["adapter"] == "mysql"
    ActiveRecord::Base.establish_connection(database_configurations["production"])
    File.open("db/production_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
  elsif database_configurations["test"]["adapter"] == "postgresql"
    `pg_dump -U #{database_configurations["test"]["username"]} -s -f db/production_structure.sql #{database_configurations["production"]["database"]}`
  end
end

desc "Drop the test database and bring it back again"
task :purge_test_database do
  if database_configurations["test"]["adapter"] == "mysql"
    ActiveRecord::Base.establish_connection(database_configurations["production"])
    ActiveRecord::Base.connection.recreate_database(database_configurations["test"]["database"])
  elsif database_configurations["test"]["adapter"] == "postgresql"
    `dropdb -U #{database_configurations["test"]["username"]} #{database_configurations["test"]["database"]}`
    `createdb -U #{database_configurations["test"]["username"]}  #{database_configurations["test"]["database"]}`
  end
end
