Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activejob'
  s.version     = '4.2.0.alpha'
  s.summary     = 'Job framework with pluggable queues (will be part of Rails).'
  s.description = 'Declare job classes that can be run by a variety of queueing backends.'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.rdoc', 'lib/**/*']
  s.require_path = 'lib'

  s.add_dependency 'activesupport', '>= 4.1.0'
  s.add_dependency 'activemodel-globalid'
end
