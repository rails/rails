path File.dirname(__FILE__)
source 'http://rubygems.org'

gem "arel", :git => "git://github.com/rails/arel.git"
gem "rails", "3.0.0.beta1"

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"

if RUBY_VERSION < '1.9'
  gem "ruby-debug", ">= 0.10.3"
end

# AR
gem "sqlite3-ruby", ">= 1.2.5", :require => 'sqlite3'

group :test do
  gem "pg", ">= 0.9.0"
  gem "mysql", ">= 2.8.1"
end

# AP
gem "rack-test", "0.5.3", :require => 'rack/test'
gem "RedCloth", ">= 4.2.2"

group :documentation do
  gem 'rdoc', '2.1'
end

if ENV['CI']
  gem "nokogiri", ">= 1.4.0"

  # fcgi gem doesn't compile on 1.9
  gem "fcgi", ">= 0.8.7" if RUBY_VERSION < '1.9.0'
end
