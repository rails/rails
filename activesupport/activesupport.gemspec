version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'activesupport'
  s.version     = version
  s.summary     = 'A toolkit of support libraries and Ruby core extensions extracted from the Rails framework.'
  s.description = 'A toolkit of support libraries and Ruby core extensions extracted from the Rails framework. Rich support for multibyte strings, internationalization, time zones, and testing.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'activesupport'

  s.files        = Dir['CHANGELOG', 'README', 'lib/**/*']
  s.require_path = 'lib'

  s.has_rdoc = true

  s.add_dependency('i18n',            '~> 0.3.6')
  s.add_dependency('tzinfo',          '~> 0.3.16')
  s.add_dependency('builder',         '~> 2.1.2')
  s.add_dependency('memcache-client', '>= 1.7.5')
end
