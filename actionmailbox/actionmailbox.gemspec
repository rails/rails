# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actionmailbox"
  s.version     = version
  s.summary     = "Inbound email handling framework."
  s.description = "Receive and process incoming emails in Rails applications."

  s.required_ruby_version = ">= 2.7.0"

  s.license  = "MIT"

  s.authors  = ["David Heinemeier Hansson", "George Claghorn"]
  s.email    = ["david@loudthinking.com", "george@basecamp.com"]
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*", "app/**/*", "config/**/*", "db/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/actionmailbox/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/actionmailbox",
    "rubygems_mfa_required" => "true",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "activerecord",  version
  s.add_dependency "activestorage", version
  s.add_dependency "activejob",     version
  s.add_dependency "actionpack",    version

  s.add_dependency "mail", ">= 2.7.1"
  s.add_dependency "net-imap"
  s.add_dependency "net-pop"
  s.add_dependency "net-smtp"
end
