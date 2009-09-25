Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'actionpack'
  s.version = '3.0.pre'
  s.summary = "Web-flow and rendering framework putting the VC in MVC."
  s.description = %q{Eases web-request routing, handling, and response as a half-way front, half-way page controller. Implemented with specific emphasis on enabling easy unit/integration testing that doesn't require a browser.} #'

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.rubyforge_project = "actionpack"
  s.homepage = "http://www.rubyonrails.org"

  s.files = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'lib/**/*']
  s.has_rdoc = true
  s.requirements << 'none'

  s.add_dependency('activesupport', '= 3.0.pre')
  s.add_dependency('activemodel',   '= 3.0.pre')
  s.add_dependency('rack', '~> 1.0.0')
  s.add_dependency('rack-test', '~> 0.5.0')

  s.require_path = 'lib'
  s.autorequire = 'action_controller'
end
