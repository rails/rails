# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actionpack"
  s.version     = version
  s.summary     = "Web-flow and rendering framework putting the VC in MVC (part of Rails)."
  s.description = "Web apps on Rails. Simple, battle-tested conventions for building and testing MVC web applications. Works with any Rack-compatible server."

  s.required_ruby_version = ">= 2.7.0"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "README.rdoc", "MIT-LICENSE", "lib/**/*"]
  s.require_path = "lib"
  s.requirements << "none"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/actionpack/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/actionpack",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version

  s.add_dependency "rack",      "~> 2.0", ">= 2.0.9"
  s.add_dependency "rack-test", ">= 0.6.3"
  s.add_dependency "rails-html-sanitizer", "~> 1.0", ">= 1.2.0"
  s.add_dependency "rails-dom-testing", "~> 2.0"
  s.add_dependency "actionview", version

  s.add_development_dependency "activemodel", version
end
