$:.unshift "lib"
require "action_pack/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionpack'
  s.version     = ActionPack::VERSION::STRING
  s.summary     = 'Web-flow and rendering framework putting the VC in MVC (part of Rails).'
  s.description = 'Web apps on Rails. Simple, battle-tested conventions for building and testing MVC web applications. Works with any Rack-compatible server.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'actionpack'

  s.files        = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.has_rdoc = true

  s.add_dependency('activesupport', "= #{ActionPack::VERSION::STRING}")
  s.add_dependency('activemodel',   "= #{ActionPack::VERSION::STRING}")
  s.add_dependency('rack',          '~> 1.1.0')
  s.add_dependency('rack-test',     '~> 0.5.0')
  s.add_dependency('rack-mount',    '~> 0.5.1')
  s.add_dependency('erubis',        '~> 2.6.5')
end
