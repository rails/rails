version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actionsystemtest"
  s.version     = version
  s.summary     = "Acceptance test framework for Rails."
  s.description = "Test framework for testing web applications by simulating how users interact with your application."

  s.required_ruby_version = ">= 2.2.2"

  s.license = "MIT"

  s.author   = ["Eileen Uchitelle", "David Heinemeier Hansson"]
  s.email    = ["eileencodes@gmail.com", "david@loudthinking.com"]
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.add_dependency "capybara",     "~> 2.7.0"
  s.add_dependency "actionpack",   version
  s.add_dependency "activesupport", version
end
