# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "minitest", "~> 5.15.0"

# Workaround until Ruby ships with cgi version 0.3.6 or higher.
gem "cgi", ">= 0.3.6", require: false

if RUBY_VERSION > "2.6"
  # We need a newish Rake since Active Job sets its test tasks' descriptions.
  gem "rake", ">= 13"
else
  gem "rake", ">= 11.1"
end

gem "capybara", ">= 3.26"
gem "selenium-webdriver", ">= 4.0.0.alpha7", "< 4.2"

gem "rack-cache", "~> 1.2"
gem "sass-rails"
gem "turbolinks", "~> 5"
gem "webpacker", "~> 5.0", require: ENV["SKIP_REQUIRE_WEBPACKER"] != "true"
# require: false so bcrypt is loaded only when has_secure_password is used.
# This is to avoid Active Model (and by extension the entire framework)
# being dependent on a binary library.
gem "bcrypt", "~> 3.1.11", require: false

# This needs to be with require false to avoid it being automatically loaded by
# sprockets.
gem "uglifier", ">= 1.3.0", require: false

# Explicitly avoid 1.x that doesn't support Ruby 2.4+
gem "json", ">= 2.0.0"

# Lock rack-test to v1 until #45467 is fixed
gem "rack-test", "< 2"

group :rubocop do
  gem "rubocop", ">= 0.90", require: false
  gem "rubocop-packaging", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
end

group :doc do
  gem "sdoc", ">= 2.3.0"
  gem "redcarpet", "~> 3.2.3", platforms: :ruby
  gem "w3c_validators", "~> 1.3.6"
  gem "kindlerb", "~> 1.2.0"
  gem "rouge"
end

# Active Support
gem "dalli"
gem "listen", "~> 3.3", require: false
gem "libxml-ruby", platforms: :ruby
gem "connection_pool", require: false
gem "rexml", require: false

# for railties
gem "bootsnap", ">= 1.4.4", require: false
gem "webrick", require: false
gem "readline-ext", require: false

# Active Job
group :job do
  gem "resque", require: false
  gem "resque-scheduler", require: false
  gem "sidekiq", require: false
  gem "sucker_punch", require: false
  gem "delayed_job", require: false
  gem "queue_classic", github: "QueueClassic/queue_classic", require: false, platforms: :ruby
  gem "sneakers", require: false
  gem "que", "< 2", require: false
  gem "backburner", require: false
  gem "delayed_job_active_record", require: false
  gem "sequel", require: false
end

# Action Cable
group :cable do
  gem "puma", ">= 5.0.3", require: false

  gem "hiredis", require: false
  gem "redis", "~> 4.0", require: false

  gem "redis-namespace", github: "resque/redis-namespace"

  gem "websocket-client-simple", github: "matthewd/websocket-client-simple", branch: "close-race", require: false

  gem "blade", require: false, platforms: [:ruby]
  gem "cookiejar", github: "yahonda/cookiejar", branch: "ruby33", require: false, platforms: [:ruby]
  gem "blade-sauce_labs_plugin", require: false, platforms: [:ruby]
  gem "sprockets-export", require: false
end

# Active Storage
group :storage do
  gem "aws-sdk-s3", require: false
  gem "google-cloud-storage", "~> 1.11", require: false
  gem "azure-storage-blob", require: false

  gem "image_processing", "~> 1.2"
end

# Action Mailbox
gem "aws-sdk-sns", require: false
gem "webmock"

group :ujs do
  gem "webdrivers"
end

# Add your own local bundler stuff.
local_gemfile = File.expand_path(".Gemfile", __dir__)
instance_eval File.read local_gemfile if File.exist? local_gemfile

group :test do
  gem "minitest-bisect", require: false
  gem "minitest-retry"
  gem "minitest-reporters"

  platforms :mri do
    gem "stackprof"
    gem "byebug"
  end

  gem "benchmark-ips"
end

platforms :ruby, :mswin, :mswin64, :mingw, :x64_mingw do
  gem "nokogiri", ">= 1.8.1"

  # Needed for compiling the ActionDispatch::Journey parser.
  gem "racc", ">=1.4.6", require: false

  # Active Record.
  gem "sqlite3", "~> 1.4"

  group :db do
    gem "pg", ">= 1.3.0.rc1"
    gem "mysql2", "~> 0.5", github: "brianmario/mysql2"
  end
end

platforms :jruby do
  if ENV["AR_JDBC"]
    gem "activerecord-jdbcsqlite3-adapter", github: "jruby/activerecord-jdbc-adapter", branch: "master"
    group :db do
      gem "activerecord-jdbcmysql-adapter", github: "jruby/activerecord-jdbc-adapter", branch: "master"
      gem "activerecord-jdbcpostgresql-adapter", github: "jruby/activerecord-jdbc-adapter", branch: "master"
    end
  else
    gem "activerecord-jdbcsqlite3-adapter", ">= 1.3.0"
    group :db do
      gem "activerecord-jdbcmysql-adapter", ">= 1.3.0"
      gem "activerecord-jdbcpostgresql-adapter", ">= 1.3.0"
    end
  end
end

platforms :rbx do
  # The rubysl-yaml gem doesn't ship with Psych by default as it needs
  # libyaml that isn't always available.
  gem "psych", "~> 3.0"
end

# Gems that are necessary for Active Record tests with Oracle.
if ENV["ORACLE_ENHANCED"]
  platforms :ruby do
    gem "ruby-oci8", "~> 2.2"
  end
  gem "activerecord-oracle_enhanced-adapter", github: "rsim/oracle-enhanced", branch: "master"
end

gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "wdm", ">= 0.1.0", platforms: [:mingw, :mswin, :x64_mingw, :mswin64]

if RUBY_VERSION < "2.6"
  # mail 2.8.0 defines net-smtp, net-imap, and net-pop as dependencies. All of
  # these gems depend on the net-protocol gem. There's an issue in Ruby <= 2.7
  # where the built in net-http uses require_relative to load built in
  # net-protocol.
  #
  # To prevent warnings from net-protocol being loaded from two different
  # places, we add net-http as an extra gem dependency so that the built in
  # net-http is never required (so that built in net-protocol is never
  # required).
  #
  # However, this workaround is impossible on Ruby 2.5 as net-http 0.1.0 has a
  # minimum ruby version of 2.6.0. So to prevent redefinition warnings, we can
  # lock mail so that the gem version of net-protocol is never required.
  gem "mail", "< 2.8.0"

  gem "strscan"
elsif RUBY_VERSION <= "3.0"
  gem "net-http", require: false
end

if RUBY_VERSION >= "3.1"
  # net-smtp, net-imap and net-pop were removed from default gems in Ruby 3.1, but is used by the `mail` gem.
  # So we need to add them as dependencies until `mail` is fixed: https://github.com/mikel/mail/pull/1439
  gem "net-smtp", require: false
  gem "net-imap", require: false
  gem "net-pop", require: false

  # digest gem, which is one of the default gems has bumped to 3.1.0.pre for ruby 3.1.0dev.
  gem "digest", "~> 3.1.0.pre", require: false

  # matrix was removed from default gems in Ruby 3.1, but is used by the `capybara` gem.
  # So we need to add it as a dependency until `capybara` is fixed: https://github.com/teamcapybara/capybara/pull/2468
  gem "matrix", require: false
end
