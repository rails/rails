version = File.read(File.expand_path("../../RAILS_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activejob"
  s.version     = version
  s.summary     = "Job framework with pluggable queues."
  s.description = "Declare job classes that can be run by a variety of queueing backends."

  s.required_ruby_version = ">= 2.2.2"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.add_dependency "activesupport", version
  s.add_dependency "globalid", ">= 0.3.6"
end
