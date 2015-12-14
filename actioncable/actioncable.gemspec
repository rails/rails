$:.unshift File.expand_path("../lib", __FILE__)
require 'action_cable/version'

Gem::Specification.new do |s|
  s.name        = 'actioncable'
  s.version     = ActionCable::VERSION
  s.summary     = 'WebSocket framework for Rails.'
  s.description = 'Structure many real-time application concerns into channels over a single WebSocket connection.'
  s.license     = 'MIT'

  s.author   = ['Pratik Naik', 'David Heinemeier Hansson']
  s.email    = ['pratiknaik@gmail.com', 'david@heinemeierhansson.com']
  s.homepage = 'http://rubyonrails.org'

  s.platform = Gem::Platform::RUBY

  s.add_dependency 'activesupport',    '>= 4.2.0'
  s.add_dependency 'actionpack',       '>= 4.2.0'
  s.add_dependency 'faye-websocket',   '~> 0.10.0'
  s.add_dependency 'websocket-driver', '~> 0.6.1'
  # Use 0.16.0 until https://github.com/celluloid/celluloid/issues/637 is resolved
  s.add_dependency 'celluloid',        '~> 0.16.0'
  s.add_dependency 'em-hiredis',       '~> 0.3.0'
  s.add_dependency 'redis',            '~> 3.0'
  s.add_dependency 'coffee-rails'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'puma'
  s.add_development_dependency 'mocha'

  s.files = Dir['README.md', 'lib/**/*']
  s.has_rdoc = false

  s.require_path = 'lib'
end
