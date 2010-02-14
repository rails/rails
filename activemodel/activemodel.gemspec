Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'activemodel'
  s.version = '3.0.0.beta1'
  s.summary = "A toolkit for building other modeling frameworks like ActiveRecord"
  s.description = %q{Extracts common modeling concerns from ActiveRecord to share between similar frameworks like ActiveResource.}
  s.required_ruby_version = '>= 1.8.7'

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.rubyforge_project = "activemodel"
  s.homepage = "http://www.rubyonrails.org"

  s.has_rdoc = true

  s.add_dependency('activesupport', '= 3.0.0.beta1')

  s.require_path = 'lib'
  s.files = Dir["CHANGELOG", "MIT-LICENSE", "README", "lib/**/*"]
end
