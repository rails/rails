$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "action_mailroom/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name     = "actionmailroom"
  s.version  = ActionMailroom::VERSION
  s.authors  = ["Jeremy Daer", "David Heinemeier Hansson"]
  s.email    = ["jeremy@basecamp.com", "david@loudthinking.com"]
  s.summary  = "Receive and process incoming emails in Rails"
  s.homepage = "https://github.com/basecamp/actionmailroom"
  s.license  = "MIT"

  s.required_ruby_version = ">= 2.5.0"

  s.add_dependency "rails", ">= 5.2.0"

  s.add_development_dependency "bundler", "~> 1.15"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "byebug"

  s.files      = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
end
