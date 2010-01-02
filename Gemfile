gem "rake", ">= 0.8.7"
gem "mocha", ">= 0.9.8"
gem "ruby-debug", ">= 0.10.3" if RUBY_VERSION < '1.9'

gem "rails", "3.0.pre", :path => "railties"
%w(activesupport activemodel actionpack actionmailer activerecord activeresource).each do |lib|
  gem lib, '3.0.pre', :path => lib
end

# AS
gem "i18n", ">= 0.3.0"

# AR
gem "arel", "0.2.pre", :git => "git://github.com/rails/arel.git"
gem "sqlite3-ruby", ">= 1.2.5"

only :test do
  gem "pg", ">= 0.8.0"
  gem "mysql", ">= 2.8.1"
end

# AP
gem "rack", "1.1.0", :git => "git://github.com/rack/rack.git"
gem "rack-test", "0.5.3"
gem "RedCloth", ">= 4.2.2"

if ENV['CI']
  disable_system_gems

  gem "nokogiri", ">= 1.4.0"
  gem "memcache-client", ">= 1.7.6"

  # fcgi gem doesn't compile on 1.9
  # avoid minitest strangeness on 1.9
  if RUBY_VERSION < '1.9.0'
    gem "fcgi", ">= 0.8.7"
  else
    gem "test-unit", ">= 2.0.5"
  end
end

disable_system_gems
