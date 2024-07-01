# frozen_string_literal: true

RAILS_VERSION_PATH = File.expand_path("../RAILS_VERSION", __dir__)
GEM_AUTHOR = "David Heinemeier Hansson"
GEM_EMAIL = "david@loudthinking.com"
GEM_HOMEPAGE = "https://rubyonrails.org"

version = File.read(RAILS_VERSION_PATH).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activejob"
  s.version     = version
  s.summary     = "Job framework with pluggable queues."
  s.description = "Declare job classes that can be run by a variety of queuing backends."

  s.required_ruby_version = ">= 3.1.0"

  s.license = "MIT"

  s.author   = GEM_AUTHOR
  s.email    = GEM_EMAIL
  s.homepage = GEM_HOMEPAGE

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/activejob/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/activejob",
    "rubygems_mfa_required" => "true",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "globalid", ">= 0.3.6"
end
