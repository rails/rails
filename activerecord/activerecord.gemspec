version = File.read(File.expand_path('../../RAILS_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activerecord'
  s.version     = version
  s.summary     = 'Object-relational mapper framework (part of Rails).'
  s.description = 'Databases on Rails. Build a persistent domain model by mapping database tables to Ruby classes. Strong conventions for associations, validations, aggregations, migrations, and testing come baked-in.'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.rdoc', 'examples/**/*', 'lib/**/*']
  s.require_path = 'lib'

  s.extra_rdoc_files = %w(README.rdoc)
  s.rdoc_options.concat ['--main',  'README.rdoc']

  s.add_dependency 'activesupport', version
  s.add_dependency 'activemodel',   version

  s.add_dependency 'arel',                            '~> 3.0.2'
  s.add_dependency 'activerecord-deprecated_finders', '0.0.1'
end
