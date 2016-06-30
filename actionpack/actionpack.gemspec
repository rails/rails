version = File.read(File.expand_path('../../RAILS_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionpack'
  s.version     = version
  s.summary     = 'Web-flow and rendering framework putting the VC in MVC (part of Rails).'
  s.description = 'Web apps on Rails. Simple, battle-tested conventions for building and testing MVC web applications. Works with any Rack-compatible server.'

  s.required_ruby_version = '>= 2.2.2'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'http://rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'README.rdoc', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'activesupport', version

  s.add_dependency 'rack',      '~> 2.0'
  s.add_dependency 'rack-test', '~> 0.6.3'
  s.add_dependency 'rails-html-sanitizer', '~> 1.0', '>= 1.0.2'
  s.add_dependency 'rails-dom-testing', '~> 2.0'
  s.add_dependency 'actionview', version

  s.add_development_dependency 'activemodel', version
end
