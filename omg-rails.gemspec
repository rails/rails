# frozen_string_literal: true

version = File.read(File.expand_path("RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "omg-rails"
  s.version     = version
  s.summary     = "Full-stack web application framework."
  s.description = "Ruby on Rails is a full-stack web framework optimized for programmer happiness and sustainable productivity. It encourages beautiful code by favoring convention over configuration."

  s.required_ruby_version     = ">= 3.1.0"
  s.required_rubygems_version = ">= 1.8.11"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "https://rubyonrails.org"

  s.files = ["README.md", "MIT-LICENSE"]

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/releases/tag/v#{version}",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}",
    "rubygems_mfa_required" => "true",
  }

  s.add_dependency "omg-activesupport", version
  s.add_dependency "omg-actionpack",    version
  s.add_dependency "omg-actionview",    version
  s.add_dependency "omg-activemodel",   version
  s.add_dependency "omg-activerecord",  version
  s.add_dependency "omg-actionmailer",  version
  s.add_dependency "omg-activejob",     version
  s.add_dependency "omg-actioncable",   version
  s.add_dependency "omg-activestorage", version
  s.add_dependency "omg-actionmailbox", version
  s.add_dependency "omg-actiontext",    version
  s.add_dependency "omg-railties",      version

  s.add_dependency "bundler", ">= 1.15.0"
end
