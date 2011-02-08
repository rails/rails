require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'

require File.join(File.dirname(__FILE__), 'lib', 'active_record', 'version')
require File.expand_path(File.dirname(__FILE__)) + "/test/config"

PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_NAME      = 'activerecord'
PKG_VERSION   = ActiveRecord::VERSION::STRING + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

RUBY_FORGE_PROJECT = "activerecord"
RUBY_FORGE_USER    = "webster132"

MYSQL_DB_USER = 'rails'

PKG_FILES = FileList[
    "lib/**/*", "test/**/*", "examples/**/*", "doc/**/*", "[A-Z]*", "install.rb", "Rakefile"
].exclude(/\bCVS\b|~$/)

def run_without_aborting(*tasks)
  errors = []

  tasks.each do |task|
    begin
      Rake::Task[task].invoke
    rescue Exception
      errors << task
    end
  end

  abort "Errors running #{errors.join(', ')}" if errors.any?
end

desc 'Run mysql, sqlite, and postgresql tests by default'
task :default => :test

desc 'Run mysql, sqlite, and postgresql tests'
task :test do
  tasks = defined?(JRUBY_VERSION) ?
    %w(test_jdbcmysql test_jdbcsqlite3 test_jdbcpostgresql) :
    %w(test_mysql test_sqlite3 test_postgresql)
  run_without_aborting(*tasks)
end

for adapter in %w( mysql postgresql sqlite sqlite3 firebird db2 oracle sybase openbase frontbase jdbcmysql jdbcpostgresql jdbcsqlite3 jdbcderby jdbch2 jdbchsqldb )
  Rake::TestTask.new("test_#{adapter}") { |t|
    if adapter =~ /jdbc/
      t.libs << "test" << "test/connections/jdbc_#{adapter}"
    else
      t.libs << "test" << "test/connections/native_#{adapter}"
    end
    adapter_short = adapter == 'db2' ? adapter : adapter[/^[a-z]+/]
    t.test_files=Dir.glob( "test/cases/**/*_test{,_#{adapter_short}}.rb" ).sort
    t.verbose = true
  }

  namespace adapter do
    task :test => "test_#{adapter}"
  end
end

namespace :mysql do
  desc 'Build the MySQL test databases'
  task :build_databases do
    %x( echo "create DATABASE activerecord_unittest DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci " | mysql --user=#{MYSQL_DB_USER})
    %x( echo "create DATABASE activerecord_unittest2 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci " | mysql --user=#{MYSQL_DB_USER})
  end

  desc 'Drop the MySQL test databases'
  task :drop_databases do
    %x( mysqladmin --user=#{MYSQL_DB_USER} -f drop activerecord_unittest )
    %x( mysqladmin --user=#{MYSQL_DB_USER} -f drop activerecord_unittest2 )
  end

  desc 'Rebuild the MySQL test databases'
  task :rebuild_databases => [:drop_databases, :build_databases]
end

task :build_mysql_databases => 'mysql:build_databases'
task :drop_mysql_databases => 'mysql:drop_databases'
task :rebuild_mysql_databases => 'mysql:rebuild_databases'


namespace :postgresql do
  desc 'Build the PostgreSQL test databases'
  task :build_databases do
    %x( createdb -E UTF8 activerecord_unittest )
    %x( createdb -E UTF8 activerecord_unittest2 )
  end

  desc 'Drop the PostgreSQL test databases'
  task :drop_databases do
    %x( dropdb activerecord_unittest )
    %x( dropdb activerecord_unittest2 )
  end

  desc 'Rebuild the PostgreSQL test databases'
  task :rebuild_databases => [:drop_databases, :build_databases]
end

task :build_postgresql_databases => 'postgresql:build_databases'
task :drop_postgresql_databases => 'postgresql:drop_databases'
task :rebuild_postgresql_databases => 'postgresql:rebuild_databases'


namespace :frontbase do
  desc 'Build the FrontBase test databases'
  task :build_databases => :rebuild_frontbase_databases

  desc 'Rebuild the FrontBase test databases'
  task :rebuild_databases do
    build_frontbase_database = Proc.new do |db_name, sql_definition_file|
      %(
        STOP DATABASE #{db_name};
        DELETE DATABASE #{db_name};
        CREATE DATABASE #{db_name};

        CONNECT TO #{db_name} AS SESSION_NAME USER _SYSTEM;
        SET COMMIT FALSE;

        CREATE USER RAILS;
        CREATE SCHEMA RAILS AUTHORIZATION RAILS;
        COMMIT;

        SET SESSION AUTHORIZATION RAILS;
        SCRIPT '#{sql_definition_file}';

        COMMIT;

        DISCONNECT ALL;
      )
    end
    create_activerecord_unittest  = build_frontbase_database['activerecord_unittest',  File.join(SCHEMA_ROOT, 'frontbase.sql')]
    create_activerecord_unittest2 = build_frontbase_database['activerecord_unittest2', File.join(SCHEMA_ROOT, 'frontbase2.sql')]
    execute_frontbase_sql = Proc.new do |sql|
      system(<<-SHELL)
      /Library/FrontBase/bin/sql92 <<-SQL
      #{sql}
      SQL
      SHELL
    end
    execute_frontbase_sql[create_activerecord_unittest]
    execute_frontbase_sql[create_activerecord_unittest2]
  end
end

task :build_frontbase_databases => 'frontbase:build_databases'
task :rebuild_frontbase_databases => 'frontbase:rebuild_databases'


# Generate the RDoc documentation

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Active Record -- Object-relation mapping put on rails"
  rdoc.options << '--line-numbers' << '--inline-source' << '-A cattr_accessor=object'
  rdoc.options << '--charset' << 'utf-8'
  rdoc.template = ENV['template'] ? "#{ENV['template']}.rb" : '../doc/template/horo'
  rdoc.rdoc_files.include('README', 'RUNNING_UNIT_TESTS', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/active_record/vendor/*')
  rdoc.rdoc_files.include('dev-utils/*.rb')
}

# Enhance rdoc task to copy referenced images also
task :rdoc do
  FileUtils.mkdir_p "doc/files/examples/"
  FileUtils.copy "examples/associations.png", "doc/files/examples/associations.png"
end


# Create compressed packages

dist_dirs = [ "lib", "test", "examples" ]

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = "Implements the ActiveRecord pattern for ORM."
  s.description = %q{Implements the ActiveRecord pattern (Fowler, PoEAA) for ORM. It ties database tables and classes together for business objects, like Customer or Subscription, that can find, save, and destroy themselves without resorting to manual SQL.}

  s.files = [ "Rakefile", "install.rb", "README", "RUNNING_UNIT_TESTS", "CHANGELOG" ]
  dist_dirs.each do |dir|
    s.files = s.files + Dir.glob( "#{dir}/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
  end

  s.add_dependency('activesupport', '= 2.3.11' + PKG_BUILD)

  s.files.delete FIXTURES_ROOT + "/fixture_database.sqlite"
  s.files.delete FIXTURES_ROOT + "/fixture_database_2.sqlite"
  s.files.delete FIXTURES_ROOT + "/fixture_database.sqlite3"
  s.files.delete FIXTURES_ROOT + "/fixture_database_2.sqlite3"
  s.require_path = 'lib'
  s.autorequire = 'active_record'

  s.has_rdoc = true
  s.extra_rdoc_files = %w( README )
  s.rdoc_options.concat ['--main',  'README']

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.homepage = "http://www.rubyonrails.org"
  s.rubyforge_project = "activerecord"
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  for file_name in FileList["lib/active_record/**/*.rb"]
    next if file_name =~ /vendor/
    f = File.open(file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end


# Publishing ------------------------------------------------------

desc "Publish the beta gem"
task :pgem => [:package] do
  require 'rake/contrib/sshpublisher'
  Rake::SshFilePublisher.new("gems.rubyonrails.org", "/u/sites/gems/gems", "pkg", "#{PKG_FILE_NAME}.gem").upload
  `ssh gems.rubyonrails.org '/u/sites/gems/gemupdate.sh'`
end

desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  require 'rake/contrib/sshpublisher'
  Rake::SshDirPublisher.new("wrath.rubyonrails.org", "public_html/ar", "doc").upload
end

desc "Publish the release files to RubyForge."
task :release => [ :package ] do
  require 'rubyforge'
  require 'rake/contrib/rubyforgepublisher'

  packages = %w( gem tgz zip ).collect{ |ext| "pkg/#{PKG_NAME}-#{PKG_VERSION}.#{ext}" }

  rubyforge = RubyForge.new
  rubyforge.login
  rubyforge.add_release(PKG_NAME, PKG_NAME, "REL #{PKG_VERSION}", *packages)
end
