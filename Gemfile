source 'http://rubygems.org'

gem "arel", :git => "git://github.com/rails/arel.git"
gem "rails", :path => File.dirname(__FILE__)

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"

group :mri do
  if RUBY_VERSION < '1.9'
    gem "system_timer"
    gem "ruby-debug", ">= 0.10.3"
  elsif RUBY_VERSION < '1.9.2' && !ENV['CI']
    gem "ruby-debug19"
  end
end

# AR
gem "sqlite3-ruby", ">= 1.2.5", :require => 'sqlite3'

group :db do
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
