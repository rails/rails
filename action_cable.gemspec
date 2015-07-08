Gem::Specification.new do |s|
  s.name        = 'action_cable'
  s.version     = '0.1.0'
  s.summary     = 'Websockets framework for Rails.'
  s.description = 'Structure many real-time application concerns into channels over a single websockets connection.'
  s.license     = 'MIT'

  s.author   = ['Pratik Naik', 'David Heinemeier Hansson']
  s.email    = ['pratiknaik@gmail.com', 'david@heinemeierhansson.com']
  s.homepage = 'http://rubyonrails.org'

  s.platform = Gem::Platform::RUBY

  s.add_dependency 'activesupport',  '>= 4.2.0'
  s.add_dependency 'faye-websocket', '~> 0.9.2'
  s.add_dependency 'celluloid',      '~> 0.16.0'
  s.add_dependency 'em-hiredis',     '~> 0.3.0'
  s.add_dependency 'redis',          '~> 3.0'

  s.files = Dir['README', 'lib/**/*']
  s.has_rdoc = false

  s.require_path = 'lib'
end
