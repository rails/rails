version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionview'
  s.version     = version
  s.summary     = 'Rendering framework putting the V in MVC (part of Rails).'
  s.description = ''

  s.required_ruby_version = '>= 1.9.3'

  s.license     = 'MIT'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'README.rdoc', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'activesupport', version
  s.add_dependency 'activemodel',   version

  s.add_dependency 'builder',       '~> 3.1.0'
  s.add_dependency 'erubis',        '~> 2.7.0'

  s.add_development_dependency 'actionpack', version
end
