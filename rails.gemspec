# frozen_string_literal: true

version = File.read(File.expand_path("RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "rails"
  s.version     = version
  s.summary     = "Full-stack web application framework."
  s.description = "Ruby on Rails is a full-stack web framework optimized for programmer happiness and sustainable productivity. It encourages beautiful code by favoring convention over configuration."

  s.required_ruby_version     = ">= 2.4.1"
  s.required_rubygems_version = ">= 1.8.11"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "http://rubyonrails.org"

  s.files = ["README.md"]

  s.add_dependency "activesupport", version
  s.add_dependency "actionpack",    version
  s.add_dependency "actionview",    version
  s.add_dependency "activemodel",   version
  s.add_dependency "activerecord",  version
  s.add_dependency "actionmailer",  version
  s.add_dependency "activejob",     version
  s.add_dependency "actioncable",   version
  s.add_dependency "activestorage", version
  s.add_dependency "railties",      version

  s.add_dependency "bundler",         ">= 1.3.0"
  s.add_dependency "sprockets-rails", ">= 2.0.0"
end
