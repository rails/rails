desc "Migrate the database according to the migrate scripts in db/migrate (only supported on PG/MySQL). A specific version can be targetted with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  Rake::Task[:db_schema_dump].invoke if ActiveRecord::Base.schema_format == :ruby
end

desc "Load fixtures into the current environment's database"
task :load_fixtures => :environment do
  require 'active_record/fixtures'
  ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
  Dir.glob(File.join(RAILS_ROOT, 'test', 'fixtures', '*.{yml,csv}')).each do |fixture_file|
    Fixtures.create_fixtures('test/fixtures', File.basename(fixture_file, '.*'))
  end
end

desc "Create a db/schema.rb file that can be portably used against any DB supported by AR."
task :db_schema_dump => :environment do
  require 'active_record/schema_dumper'
  File.open(ENV['SCHEMA'] || "db/schema.rb", "w") do |file|
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
  end
end

desc "Import a schema.rb file into the database."
task :db_schema_import => :environment do
  file = ENV['SCHEMA'] || "db/schema.rb"
  load file
end

desc "Recreate the test database from the current environment's database schema."
task :clone_schema_to_test => :db_schema_dump do
  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
  Rake::Task[:db_schema_import].invoke
end

desc "Dump the database structure to a SQL file"
task :db_structure_dump => :environment do
  abcs = ActiveRecord::Base.configurations
  case abcs[RAILS_ENV]["adapter"] 
    when "mysql", "oci"
      ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
      File.open("db/#{RAILS_ENV}_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
    when "postgresql"
      ENV['PGHOST']     = abcs[RAILS_ENV]["host"] if abcs[RAILS_ENV]["host"]
      ENV['PGPORT']     = abcs[RAILS_ENV]["port"].to_s if abcs[RAILS_ENV]["port"]
      ENV['PGPASSWORD'] = abcs[RAILS_ENV]["password"].to_s if abcs[RAILS_ENV]["password"]
      search_path = abcs[RAILS_ENV]["schema_search_path"]
      search_path = "--schema=#{search_path}" if search_path
      `pg_dump -U "#{abcs[RAILS_ENV]["username"]}" -s -x -O -f db/#{RAILS_ENV}_structure.sql #{search_path} #{abcs[RAILS_ENV]["database"]}`
    when "sqlite", "sqlite3"
      dbfile = abcs[RAILS_ENV]["database"] || abcs[RAILS_ENV]["dbfile"]
      `#{abcs[RAILS_ENV]["adapter"]} #{dbfile} .schema > db/#{RAILS_ENV}_structure.sql`
    when "sqlserver"
      `scptxfr /s #{abcs[RAILS_ENV]["host"]} /d #{abcs[RAILS_ENV]["database"]} /I /f db\\#{RAILS_ENV}_structure.sql /q /A /r`
      `scptxfr /s #{abcs[RAILS_ENV]["host"]} /d #{abcs[RAILS_ENV]["database"]} /I /F db\ /q /A /r`
    else 
      raise "Task not supported by '#{abcs["test"]["adapter"]}'"
  end

  if ActiveRecord::Base.connection.supports_migrations?
    File.open("db/#{RAILS_ENV}_structure.sql", "a") { |f| f << ActiveRecord::Base.connection.dump_schema_information }
  end
end

desc "Recreate the test databases from the development structure"
task :clone_structure_to_test => [ :db_structure_dump, :purge_test_database ] do
  abcs = ActiveRecord::Base.configurations
  case abcs["test"]["adapter"]
    when "mysql"
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
      dbfile = abcs["test"]["database"] || abcs["test"]["dbfile"]
      `#{abcs["test"]["adapter"]} #{dbfile} < db/#{RAILS_ENV}_structure.sql`
    when "sqlserver"
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{RAILS_ENV}_structure.sql`
    when "oci"
      ActiveRecord::Base.establish_connection(:test)
      IO.readlines("db/#{RAILS_ENV}_structure.sql").join.split(";\n\n").each do |ddl|
        ActiveRecord::Base.connection.execute(ddl)
      end
    else 
      raise "Task not supported by '#{abcs["test"]["adapter"]}'"
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
      enc_option = "-E #{abcs["test"]["encoding"]}" if abcs["test"]["encoding"]
      `dropdb -U "#{abcs["test"]["username"]}" #{abcs["test"]["database"]}`
      `createdb #{enc_option} -U "#{abcs["test"]["username"]}" #{abcs["test"]["database"]}`
    when "sqlite","sqlite3"
      dbfile = abcs["test"]["database"] || abcs["test"]["dbfile"]
      File.delete(dbfile) if File.exist?(dbfile)
    when "sqlserver"
      dropfkscript = "#{abcs["test"]["host"]}.#{abcs["test"]["database"]}.DP1".gsub(/\\/,'-')
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{dropfkscript}`
      `osql -E -S #{abcs["test"]["host"]} -d #{abcs["test"]["database"]} -i db\\#{RAILS_ENV}_structure.sql`
    when "oci"
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
        ActiveRecord::Base.connection.execute(ddl)
      end
    else
      raise "Task not supported by '#{abcs["test"]["adapter"]}'"
  end
end

def prepare_test_database_task
  {:sql  => :clone_structure_to_test, 
   :ruby => :clone_schema_to_test}[ActiveRecord::Base.schema_format]
end

desc 'Prepare the test database and load the schema'
task :prepare_test_database => :environment do
  Rake::Task[prepare_test_database_task].invoke
end

desc "Creates a sessions table for use with CGI::Session::ActiveRecordStore"
task :create_sessions_table => :environment do
  raise "Task unavailable to this database (no migration support)" unless ActiveRecord::Base.connection.supports_migrations?

  ActiveRecord::Base.connection.create_table :sessions do |t|
    t.column :session_id, :string
    t.column :data, :text
    t.column :updated_at, :datetime
  end
  
  ActiveRecord::Base.connection.add_index :sessions, :session_id
end

desc "Drop the sessions table"
task :drop_sessions_table => :environment do
  raise "Task unavailable to this database (no migration support)" unless ActiveRecord::Base.connection.supports_migrations?
  
  ActiveRecord::Base.connection.drop_table :sessions
end

desc "Drop and recreate the session table (much faster than 'DELETE * FROM sessions')"
task :purge_sessions_table => [ :drop_sessions_table, :create_sessions_table ] do
end
