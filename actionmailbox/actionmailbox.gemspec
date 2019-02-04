# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actionmailbox"
  s.version     = version
  s.summary     = "Inbound email handling framework."
  s.description = "Receive and process incoming emails in Rails applications."

  s.required_ruby_version = ">= 2.5.0"

  s.license  = "MIT"

  s.authors  = ["David Heinemeier Hansson", "George Claghorn"]
  s.email    = ["david@loudthinking.com", "george@basecamp.com"]
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*", "app/**/*", "config/**/*", "db/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/actionmailbox",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/actionmailbox/CHANGELOG.md"
  }

  s.post_install_message = %q{
    To use Action Mailbox, Install migrations needed for InboundEmail and ensure Active Storage is set up.
    See: https://guides.rubyonrails.org/action_mailbox_basics.html
    rails action_mailbox:install

    rails db:migrate
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "activerecord",  version
  s.add_dependency "activestorage", version
  s.add_dependency "activejob",     version
  s.add_dependency "actionpack",    version

  s.add_dependency "mail", ">= 2.7.1"
end
