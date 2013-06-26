version = File.read(File.expand_path('../../RAILS_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activemodel'
  s.version     = version
  s.summary     = 'A toolkit for building modeling frameworks (part of Rails).'
  s.description = 'A toolkit for building modeling frameworks like Active Record. Rich support for attributes, callbacks, validations, observers, serialization, internationalization, and testing.'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.rdoc', 'lib/**/*']
  s.require_path = 'lib'

  s.add_dependency 'activesupport', version

  s.add_dependency 'builder', '~> 3.1.0'
end
