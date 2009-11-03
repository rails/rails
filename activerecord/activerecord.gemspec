Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'activerecord'
  s.version = '3.0.pre'
  s.summary = "Implements the ActiveRecord pattern for ORM."
  s.description = %q{Implements the ActiveRecord pattern (Fowler, PoEAA) for ORM. It ties database tables and classes together for business objects, like Customer or Subscription, that can find, save, and destroy themselves without resorting to manual SQL.}

  s.files = Dir['CHANGELOG', 'README', 'examples/**/*', 'lib/**/*']

  s.add_dependency('activesupport', '= 3.0.pre')
  s.add_dependency('activemodel',   '= 3.0.pre')
  s.add_dependency('arel',          '~> 0.1.1')

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
