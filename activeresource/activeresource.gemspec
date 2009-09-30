Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'activeresource'
  s.version = '3.0.pre'
  s.summary = "Think Active Record for web resources."
  s.description = %q{Wraps web resources in model classes that can be manipulated through XML over REST.}

  s.files = Dir['CHANGELOG', 'README', 'examples/**/*', 'lib/**/*']

  s.add_dependency('activesupport', '= 3.0.pre')
  s.add_dependency('activemodel',   '= 3.0.pre')

  s.require_path = 'lib'
  s.autorequire = 'active_resource'

  s.has_rdoc = true
  s.extra_rdoc_files = %w( README )
  s.rdoc_options.concat ['--main',  'README']

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.homepage = "http://www.rubyonrails.org"
  s.rubyforge_project = "activeresource"
end
