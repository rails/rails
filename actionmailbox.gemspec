$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "action_mailbox/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name     = "actionmailbox"
  s.version  = ActionMailbox::VERSION
  s.authors  = ["David Heinemeier Hansson", "George Claghorn"]
  s.email    = ["david@loudthinking.com", "george@basecamp.com"]
  s.summary  = "Receive and process incoming emails in Rails"
  s.homepage = "https://github.com/rails/actionmailbox"
  s.license  = "MIT"

  s.required_ruby_version = ">= 2.5.0"

  s.add_dependency "rails", ">= 5.2.0"

  s.add_development_dependency "bundler", "~> 1.15"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "byebug"
  s.add_development_dependency "webmock"

  s.files      = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
end
