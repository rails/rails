require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$VERBOSE = nil

require File.dirname(__FILE__) + '/config/environment'
require 'code_statistics'

desc "Run all the tests on a fresh test database"
task :default => [ :clone_structure_to_test, :test_units, :test_functional ]

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
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('vendor/railties/lib/breakpoint.rb')
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
  rdoc.rdoc_files.include('vendor/actionmailer/README')
  rdoc.rdoc_files.include('vendor/actionmailer/CHANGELOG')
  rdoc.rdoc_files.include('vendor/actionmailer/lib/action_mailer/base.rb')
}

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  CodeStatistics.new(
    ["Helpers", "app/helpers"], 
    ["Controllers", "app/controllers"], 
    ["Functionals", "test/functional"],
    ["Models", "app/models"],
    ["Units", "test/unit"]
  ).to_s
end

desc "Recreate the test databases from the development structure"
task :clone_structure_to_test => [ :db_structure_dump, :purge_test_database ] do
  abcs = ActiveRecord::Base.configurations
  case abcs["test"]["adapter"]
    when  "mysql"
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
      IO.readlines("db/#{RAILS_ENV}_structure.sql").join.split("\n\n").each do |table|
        ActiveRecord::Base.connection.execute(table)
      end
    when  "postgresql"
      `psql -U #{abcs["test"]["username"]} -f db/#{RAILS_ENV}_structure.sql #{abcs["test"]["database"]}`
    when "sqlite", "sqlite3"
      `#{abcs[RAILS_ENV]["adapter"]} #{abcs["test"]["dbfile"]} < db/#{RAILS_ENV}_structure.sql`
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end

desc "Dump the database structure to a SQL file"
task :db_structure_dump do
  abcs = ActiveRecord::Base.configurations
  case abcs[RAILS_ENV]["adapter"] 
    when "mysql"
      ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
      File.open("db/#{RAILS_ENV}_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
    when  "postgresql"
      `pg_dump -U #{abcs[RAILS_ENV]["username"]} -s -f db/#{RAILS_ENV}_structure.sql #{abcs[RAILS_ENV]["database"]}`
    when "sqlite", "sqlite3"
      `#{abcs[RAILS_ENV]["adapter"]} #{abcs[RAILS_ENV]["dbfile"]} .schema > db/#{RAILS_ENV}_structure.sql`
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end

desc "Empty the test database"
task :purge_test_database do
  abcs = ActiveRecord::Base.configurations
  case abcs["test"]["adapter"]
    when "mysql"
      ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
      ActiveRecord::Base.connection.recreate_database(abcs["test"]["database"])
    when "postgresql"
      `dropdb -U #{abcs["test"]["username"]} #{abcs["test"]["database"]}`
      `createdb -U #{abcs["test"]["username"]}  #{abcs["test"]["database"]}`
    when "sqlite","sqlite3"
      File.delete(abcs["test"]["dbfile"]) if File.exist?(abcs["test"]["dbfile"])
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end
