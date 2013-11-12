version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).chomp

Gem::Specification.new do |s|
  s.name = 'rails'
  s.version = version
  s.summary = 'Web-application framework with template engine, control-flow layer, and ORM.'
  s.description = "Rails is a framework for building web-application using CGI, FCGI, mod_ruby, or WEBrick\non top of either MySQL, PostgreSQL, SQLite, DB2, SQL Server, or Oracle with eRuby- or Builder-based templates."

  s.author = 'David Heinemeier Hansson'
  s.email = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.require_path = 'lib'
  s.files = ['bin/rails']
  s.executables = ['rails']
  s.rdoc_options = ['--exclude', '.']

  s.add_dependency 'rake',           '>= 0.8.3'
  s.add_dependency 'activesupport',  "= #{version}"
  s.add_dependency 'activerecord',   "= #{version}"
  s.add_dependency 'actionpack',     "= #{version}"
  s.add_dependency 'actionmailer',   "= #{version}"
end
