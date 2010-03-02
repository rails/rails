$:.unshift "lib"
require "active_record/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activerecord'
  s.version     = ActiveRecord::VERSION::STRING
  s.summary     = 'Object-relational mapper framework (part of Rails).'
  s.description = 'Databases on Rails. Build a persistent domain model by mapping database tables to Ruby classes. Strong conventions for associations, validations, aggregations, migrations, and testing come baked-in.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'activerecord'

  s.files        = Dir['CHANGELOG', 'README', 'examples/**/*', 'lib/**/*']
  s.require_path = 'lib'

  s.has_rdoc         = true
  s.extra_rdoc_files = %w( README )
  s.rdoc_options.concat ['--main',  'README']

  s.add_dependency('activesupport', "= #{ActiveRecord::VERSION::STRING}")
  s.add_dependency('activemodel',   "= #{ActiveRecord::VERSION::STRING}")
  s.add_dependency('arel',          '~> 0.2.1')
end
