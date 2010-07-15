source 'http://rubygems.org'

gem "arel", :git => "git://github.com/rails/arel.git"
gem "rails", :path => File.dirname(__FILE__)

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"
gem "rdoc",  "2.2"

mri = !defined?(RUBY_ENGINE) || RUBY_ENGINE == "ruby"
if mri && RUBY_VERSION < '1.9'
  gem "system_timer"
  gem "ruby-debug", ">= 0.10.3"
end

if mri || RUBY_ENGINE == "rbx"
  gem 'json'
  gem 'yajl-ruby'
  gem "nokogiri", ">= 1.4.2"
elsif RUBY_ENGINE == "jruby"
  gem "ruby-debug"
  gem "jruby-openssl"
end

# AS
gem "memcache-client", ">= 1.8.5"

# AM
gem "text-format", "~> 1.0.0"

# AR
if mri || RUBY_ENGINE == "rbx"
  gem "sqlite3-ruby", "~> 1.3.1", :require => 'sqlite3'

  group :db do
    gem "pg", ">= 0.9.0"
    gem "mysql", ">= 2.8.1"
  end
elsif RUBY_ENGINE == "jruby"
  gem "activerecord-jdbcsqlite3-adapter"

  group :db do
    gem "activerecord-jdbcmysql-adapter"
    gem "activerecord-jdbcpostgresql-adapter"
  end
end

if ENV['CI']
  gem "nokogiri", ">= 1.4.2"

  # fcgi gem doesn't compile on 1.9
  gem "fcgi", ">= 0.8.8" if RUBY_VERSION < '1.9.0'
end
