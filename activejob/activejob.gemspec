# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activejob"
  s.version     = version
  s.summary     = "Job framework with pluggable queues."
  s.description = "Declare job classes that can be run by a variety of queuing backends."

  s.required_ruby_version = ">= 2.7.0"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/activejob/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/activejob",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "globalid", ">= 0.3.6"
end
