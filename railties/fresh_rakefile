require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$VERBOSE = nil
TEST_CHANGES_SINCE = Time.now - 600

desc "Run all the tests on a fresh test database"
task :default => [ :test_units, :test_functional ]


desc 'Require application environment.'
task :environment do
  unless defined? RAILS_ROOT
    require File.dirname(__FILE__) + '/config/environment'
  end
end

desc "Generate API documentation, show coding stats"
task :doc => [ :appdoc, :stats ]


# Look up tests for recently modified sources.
def recent_tests(source_pattern, test_path, touched_since = 10.minutes.ago)
  FileList[source_pattern].map do |path|
    if File.mtime(path) > touched_since
      test = "#{test_path}/#{File.basename(path, '.rb')}_test.rb"
      test if File.exists?(test)
    end
  end.compact
end

desc 'Test recent changes.'
Rake::TestTask.new(:recent => [ :clone_structure_to_test ]) do |t|
  since = TEST_CHANGES_SINCE
  touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
    recent_tests('app/models/*.rb', 'test/unit', since) +
    recent_tests('app/controllers/*.rb', 'test/functional', since)

  t.libs << 'test'
  t.verbose = true
  t.test_files = touched.uniq
end
task :test_recent => [ :clone_structure_to_test ]

desc "Run the unit tests in test/unit"
Rake::TestTask.new("test_units") { |t|
  t.libs << "test"
  t.pattern = 'test/unit/**/*_test.rb'
  t.verbose = true
}
task :test_units => [ :clone_structure_to_test ]

desc "Run the functional tests in test/functional"
Rake::TestTask.new("test_functional") { |t|
  t.libs << "test"
  t.pattern = 'test/functional/**/*_test.rb'
  t.verbose = true
}
task :test_functional => [ :clone_structure_to_test ]

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
  rdoc.template = "#{ENV['template']}.rb" if ENV['template']
  rdoc.title    = "Rails Framework Documentation"
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/railties/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/railties/MIT-LICENSE')
  rdoc.rdoc_files.include('vendor/rails/activerecord/README')
  rdoc.rdoc_files.include('vendor/rails/activerecord/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('vendor/rails/activerecord/lib/active_record/vendor/*')
  rdoc.rdoc_files.include('vendor/rails/actionpack/README')
  rdoc.rdoc_files.include('vendor/rails/actionpack/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_view/**/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/README')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/lib/action_mailer/base.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/README')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/api/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/client/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/container/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/dispatcher/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/protocol/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/support/*.rb')
  rdoc.rdoc_files.include('vendor/rails/activesupport/README')
  rdoc.rdoc_files.include('vendor/rails/activesupport/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/activesupport/lib/active_support/**/*.rb')
}

desc "Report code statistics (KLOCs, etc) from the application"
task :stats => [ :environment ] do
  require 'code_statistics'
  CodeStatistics.new(
    ["Helpers", "app/helpers"], 
    ["Controllers", "app/controllers"], 
    ["APIs", "app/apis"],
    ["Components", "components"],
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
    when "postgresql"
      ENV['PGHOST']     = abcs["test"]["host"] if abcs["test"]["host"]
      ENV['PGPORT']     = abcs["test"]["port"].to_s if abcs["test"]["port"]
      ENV['PGPASSWORD'] = abcs["test"]["password"].to_s if abcs["test"]["password"]
      `psql -U "#{abcs["test"]["username"]}" -f db/#{RAILS_ENV}_structure.sql #{abcs["test"]["database"]}`
    when "sqlite", "sqlite3"
      `#{abcs[RAILS_ENV]["adapter"]} #{abcs["test"]["dbfile"]} < db/#{RAILS_ENV}_structure.sql`
    when "sqlserver"
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{RAILS_ENV}_structure.sql`
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end

desc "Dump the database structure to a SQL file"
task :db_structure_dump => :environment do
  abcs = ActiveRecord::Base.configurations
  case abcs[RAILS_ENV]["adapter"] 
    when "mysql"
      ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
      File.open("db/#{RAILS_ENV}_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
    when "postgresql"
      ENV['PGHOST']     = abcs[RAILS_ENV]["host"] if abcs[RAILS_ENV]["host"]
      ENV['PGPORT']     = abcs[RAILS_ENV]["port"].to_s if abcs[RAILS_ENV]["port"]
      ENV['PGPASSWORD'] = abcs[RAILS_ENV]["password"].to_s if abcs[RAILS_ENV]["password"]
      `pg_dump -U "#{abcs[RAILS_ENV]["username"]}" -s -x -O -f db/#{RAILS_ENV}_structure.sql #{abcs[RAILS_ENV]["database"]}`
    when "sqlite", "sqlite3"
      `#{abcs[RAILS_ENV]["adapter"]} #{abcs[RAILS_ENV]["dbfile"]} .schema > db/#{RAILS_ENV}_structure.sql`
    when "sqlserver"
      `scptxfr /s #{abcs[RAILS_ENV]["host"]} /d #{abcs[RAILS_ENV]["database"]} /I /f db\\#{RAILS_ENV}_structure.sql /q /A /r`
      `scptxfr /s #{abcs[RAILS_ENV]["host"]} /d #{abcs[RAILS_ENV]["database"]} /I /F db\ /q /A /r`
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end

desc "Empty the test database"
task :purge_test_database => :environment do
  abcs = ActiveRecord::Base.configurations
  case abcs["test"]["adapter"]
    when "mysql"
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Base.connection.recreate_database(abcs["test"]["database"])
    when "postgresql"
      ENV['PGHOST']     = abcs["test"]["host"] if abcs["test"]["host"]
      ENV['PGPORT']     = abcs["test"]["port"].to_s if abcs["test"]["port"]
      ENV['PGPASSWORD'] = abcs["test"]["password"].to_s if abcs["test"]["password"]
      `dropdb -U "#{abcs["test"]["username"]}" #{abcs["test"]["database"]}`
      `createdb -T template0 -U "#{abcs["test"]["username"]}" #{abcs["test"]["database"]}`
    when "sqlite","sqlite3"
      File.delete(abcs["test"]["dbfile"]) if File.exist?(abcs["test"]["dbfile"])
    when "sqlserver"
      dropfkscript = "#{abcs["test"]["host"]}.#{abcs["test"]["database"]}.DP1".gsub(/\\/,'-')
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{dropfkscript}`
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{RAILS_ENV}_structure.sql`
    else 
      raise "Unknown database adapter '#{abcs["test"]["adapter"]}'"
  end
end

desc "Clears all *.log files in log/"
task :clear_logs => :environment do
  FileList["log/*.log"].each do |log_file|
    f = File.open(log_file, "w")
    f.close
  end
end

desc "Migrate the database according to the migrate scripts in db/migrate (only supported on PG/MySQL). A specific version can be targetted with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/db/migrate/', ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
end