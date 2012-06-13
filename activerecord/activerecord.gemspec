require File.join(File.dirname(__FILE__), 'lib', 'active_record', 'version')
require File.expand_path(File.dirname(__FILE__)) + "/test/config"

PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_NAME      = 'activerecord'
PKG_VERSION   = ActiveRecord::VERSION::STRING + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

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

  s.add_dependency('activesupport', '= 2.3.14' + PKG_BUILD)

  s.files.delete FIXTURES_ROOT + "/fixture_database.sqlite"
  s.files.delete FIXTURES_ROOT + "/fixture_database_2.sqlite"
  s.files.delete FIXTURES_ROOT + "/fixture_database.sqlite3"
  s.files.delete FIXTURES_ROOT + "/fixture_database_2.sqlite3"
  s.require_path = 'lib'

  s.extra_rdoc_files = %w( README )
  s.rdoc_options.concat ['--main',  'README']

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.homepage = "http://www.rubyonrails.org"
  s.rubyforge_project = "activerecord"
end


