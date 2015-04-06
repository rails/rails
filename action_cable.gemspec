Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'action_cable'
  s.version = '0.0.2'
  s.summary = 'Framework for websockets.'
  s.description = 'Action Cable is a framework for realtime communication over websockets.'

  s.author = ['Pratik Naik']
  s.email = ['pratiknaik@gmail.com']
  s.homepage = 'http://basecamp.com'

  s.add_dependency('activesupport', '>= 4.2.0')
  s.add_dependency('faye-websocket', '~> 0.9.2')
  s.add_dependency('celluloid', '~> 0.16.0')
  s.add_dependency('em-hiredis', '~> 0.3.0')
  s.add_dependency('redis', '~> 3.0')

  s.files = Dir['README', 'lib/**/*']
  s.has_rdoc = false

  s.require_path = 'lib'
end
