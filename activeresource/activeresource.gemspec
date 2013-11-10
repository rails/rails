version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).chomp

Gem::Specification.new do |s|
  s.name = 'activeresource'
  s.version = version
  s.summary = 'Think Active Record for web resources.'
  s.description = 'Wraps web resources in model classes that can be manipulated through XML over REST.'

  s.author = 'David Heinemeier Hansson'
  s.email = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.require_path = 'lib'
  s.files = ['README']
  s.rdoc_options = ['--main', 'README']
  s.extra_rdoc_files = ['README']

  s.add_dependency 'activesupport', "= #{version}"
end
