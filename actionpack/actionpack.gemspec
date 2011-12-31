version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionpack'
  s.version     = version
  s.summary     = 'Web-flow and rendering framework putting the VC in MVC (part of Rails).'
  s.description = 'Web apps on Rails. Simple, battle-tested conventions for building and testing MVC web applications. Works with any Rack-compatible server.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'actionpack'

  s.files        = Dir['CHANGELOG', 'README.rdoc', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency('activesupport', version)
  s.add_dependency('activemodel',   version)
  s.add_dependency('builder',       '~> 2.1.2')
  s.add_dependency('i18n',          '~> 0.5.0')
  s.add_dependency('rack',          '~> 1.2.5')
  s.add_dependency('rack-test',     '~> 0.5.7')
  s.add_dependency('rack-mount',    '~> 0.6.14')
  s.add_dependency('tzinfo',        '~> 0.3.23')
  s.add_dependency('erubis',        '~> 2.6.6')
end
