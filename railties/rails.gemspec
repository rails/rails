Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'rails'
  s.version = '3.0.pre'
  s.summary = "Web-application framework with template engine, control-flow layer, and ORM."
  s.description = <<-EOF
    Rails is a framework for building web-application using CGI, FCGI, mod_ruby, or WEBrick
    on top of either MySQL, PostgreSQL, SQLite, DB2, SQL Server, or Oracle with eRuby- or Builder-based templates.
  EOF

  s.add_dependency('rake', '>= 0.8.3')
  s.add_dependency('activesupport',    '= 3.0.pre')
  s.add_dependency('activerecord',     '= 3.0.pre')
  s.add_dependency('actionpack',       '= 3.0.pre')
  s.add_dependency('actionmailer',     '= 3.0.pre')
  s.add_dependency('activeresource',   '= 3.0.pre')

  s.rdoc_options << '--exclude' << '.'
  s.has_rdoc = false

  s.files = Dir['CHANGELOG', 'README', 'bin/**/*', 'builtin/**/*', 'guides/**/*', 'lib/**/{*,.[a-z]*}']
  s.require_path = 'lib'
  s.bindir = "bin"
  s.executables = ["rails"]
  s.default_executable = "rails"

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.homepage = "http://www.rubyonrails.org"
  s.rubyforge_project = "rails"
end
