# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activerecord"
  s.version     = version
  s.summary     = "Object-relational mapper framework (part of Rails)."
  s.description = "Databases on Rails. Build a persistent domain model by mapping database tables to Ruby classes. Strong conventions for associations, validations, aggregations, migrations, and testing come baked-in."

  s.required_ruby_version = ">= 3.2.0"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.rdoc", "examples/**/*", "lib/**/*"]
  s.require_path = "lib"

  s.extra_rdoc_files = %w(README.rdoc)
  s.rdoc_options.concat ["--main",  "README.rdoc"]

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/activerecord/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/activerecord",
    "rubygems_mfa_required" => "true",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "activemodel",   version
  s.add_dependency "timeout", ">= 0.4.0"
end
