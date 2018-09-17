$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "action_text/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name     = "actiontext"
  s.version  = ActionText::VERSION
  s.authors  = ["Javan Makhmali", "Sam Stephenson", "David Heinemeier Hansson"]
  s.email    = ["javan@javan.us", "sstephenson@gmail.com", "david@loudthinking.com"]
  s.summary  = "Edit and display rich text in Rails applications"
  s.homepage = "https://github.com/basecamp/actiontext"
  s.license  = "MIT"

  s.required_ruby_version = ">= 2.2.2"

  s.add_dependency "rails", ">= 5.2.0"
  s.add_dependency "nokogiri"

  s.add_development_dependency "bundler", "~> 1.15"
  s.add_development_dependency "mini_magick"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "webpacker", "~> 3.2.2"

  s.files      = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
end
