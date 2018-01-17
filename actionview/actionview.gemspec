# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actionview"
  s.version     = version
  s.summary     = "Rendering framework putting the V in MVC (part of Rails)."
  s.description = "Simple, battle-tested conventions and helpers for building web pages."

  s.required_ruby_version = ">= 2.2.2"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "README.rdoc", "MIT-LICENSE", "lib/**/*"]
  s.require_path = "lib"
  s.requirements << "none"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/actionview",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/actionview/CHANGELOG.md"
  }

  s.add_dependency "activesupport", version

  s.add_dependency "builder",       "~> 3.1"
  s.add_dependency "erubi",         "~> 1.4"
  s.add_dependency "rails-html-sanitizer", "~> 1.0", ">= 1.0.3"
  s.add_dependency "rails-dom-testing", "~> 2.0"

  s.add_development_dependency "actionpack",  version
  s.add_development_dependency "activemodel", version
end
