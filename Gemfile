# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "minitest"

# We need a newish Rake since Active Job sets its test tasks' descriptions.
gem "rake", ">= 13"

gem "releaser", path: "tools/releaser"

gem "sprockets-rails", ">= 2.0.0", require: false
gem "propshaft", ">= 0.1.7", "!= 1.0.1"
gem "capybara", ">= 3.39"
gem "selenium-webdriver", ">= 4.20.0"

gem "rack-cache", "~> 1.2"
gem "stimulus-rails"
gem "turbo-rails"
gem "jsbundling-rails"
gem "cssbundling-rails"
gem "importmap-rails", ">= 1.2.3"
gem "tailwindcss-rails"
gem "dartsass-rails"
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "kamal", ">= 2.1.0", require: false
gem "thruster", require: false
# require: false so bcrypt is loaded only when has_secure_password is used.
# This is to avoid Active Model (and by extension the entire framework)
# being dependent on a binary library.
gem "bcrypt", "~> 3.1.11", require: false

# This needs to be with require false to avoid it being automatically loaded by
# sprockets.
gem "terser", ">= 1.1.4", require: false

# Explicitly avoid 1.x that doesn't support Ruby 2.4+
gem "json", ">= 2.0.0", "!=2.7.0"

# Workaround until all supported Ruby versions ship with uri version 0.13.1 or higher.
gem "uri", ">= 0.13.1", require: false

gem "prism"

group :rubocop do
  gem "rubocop", ">= 1.25.1", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-packaging", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-md", require: false

  # This gem is used in Railties tests so it must be a development dependency.
  gem "rubocop-rails-omakase", require: false
end

group :mdl do
  gem "mdl", "!= 0.13.0", require: false
end

group :doc do
  gem "sdoc", git: "https://github.com/rails/sdoc.git", branch: "main"
  gem "rdoc", "< 6.10"
  gem "redcarpet", "~> 3.2.3", platforms: :ruby
  gem "w3c_validators", "~> 1.3.6"
  gem "rouge"
  gem "rubyzip", "~> 2.0"
end

# Active Support
gem "dalli", ">= 3.0.1"
gem "listen", "~> 3.3", require: false
gem "libxml-ruby", platforms: :ruby
gem "connection_pool", require: false
gem "rexml", require: false
gem "msgpack", ">= 1.7.0", require: false

# for railties
gem "bootsnap", ">= 1.4.4", require: false
gem "webrick", require: false
gem "jbuilder", require: false
gem "web-console", require: false

# Action Pack and railties
rack_version = ENV.fetch("RACK", "~> 3.0")
if rack_version != "head"
  gem "rack", rack_version
else
  gem "rack", git: "https://github.com/rack/rack.git", branch: "main"
end

gem "useragent", require: false

# Active Job
group :job do
  gem "resque", require: false
  gem "resque-scheduler", require: false
  gem "sidekiq", require: false
  gem "sucker_punch", require: false
  gem "queue_classic", ">= 4.0.0", require: false, platforms: :ruby
  gem "sneakers", require: false
  gem "backburner", require: false
end

# Action Cable
group :cable do
  gem "puma", ">= 5.0.3", require: false

  gem "redis", ">= 4.0.1", require: false

  gem "redis-namespace"

  gem "websocket-client-simple", require: false
end

# Active Storage
group :storage do
  gem "aws-sdk-s3", require: false
  gem "google-cloud-storage", "~> 1.11", require: false
  gem "azure-storage-blob", "~> 2.0", require: false

  gem "image_processing", "~> 1.2"
end

# Action Mailbox
gem "aws-sdk-sns", require: false
gem "webmock"
gem "httpclient", github: "nahi/httpclient", branch: "master", require: false

# Add your own local bundler stuff.
local_gemfile = File.expand_path(".Gemfile", __dir__)
instance_eval File.read local_gemfile if File.exist? local_gemfile

group :test do
  gem "minitest-bisect", require: false
  gem "minitest-ci", require: false
  gem "minitest-retry"

  platforms :mri do
    gem "stackprof"
    gem "debug", ">= 1.1.0", require: false
  end

  # Needed for Railties tests because it is included in generated apps.
  gem "brakeman"
end

platforms :ruby, :windows do
  gem "nokogiri", ">= 1.8.1", "!= 1.11.0"

  # Active Record.
  gem "sqlite3", ">= 2.1"

  group :db do
    gem "pg", "~> 1.3"
    gem "mysql2", "~> 0.5"
    gem "trilogy", ">= 2.7.0"
  end
end

gem "tzinfo-data", platforms: [:windows, :jruby]
gem "wdm", ">= 0.1.0", platforms: [:windows]

gem "launchy"
