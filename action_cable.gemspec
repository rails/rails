Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'action_cable'
  s.version = '0.0.1'
  s.summary = 'Framework for websockets.'
  s.description = 'Action Cable is a framework for realtime communication over websockets.'

  s.author = ['Pratik Naik']
  s.email = ['pratiknaik@gmail.com']
  s.homepage = 'http://basecamp.com'

  s.add_dependency('activesupport',   '~> 4.2.0')
  s.add_dependency('cramp',           '~> 0.15.4')

  s.files = Dir['README', 'lib/**/*']
  s.has_rdoc = false

  s.require_path = 'lib'
end
