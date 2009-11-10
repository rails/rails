clear_sources
source 'http://gemcutter.org'

gem "rake", ">= 0.8.7"
gem "mocha", ">= 0.9.8"

gem "rails", "3.0.pre", :vendored_at => "railties"
%w(activesupport activemodel actionpack actionmailer activerecord activeresource).each do |lib|
  gem lib, '3.0.pre', :vendored_at => lib
end

# AR
gem "arel", "0.2.pre", :git => "git://github.com/rails/arel.git"
gem "sqlite3-ruby", ">= 1.2.5"

# AP
gem "rack", "1.0.1", :git => "git://github.com/rails/rack.git"
gem "rack-mount", :git => "git://github.com/rails/rack-mount.git"
gem "rack-test", ">= 0.5.0"
gem "erubis", ">= 2.6.5"
gem "RedCloth", ">= 4.2.2"

only :ci do
  gem "fcgi", ">= 0.8.7" if RUBY_VERSION <= '1.9.0'
  gem "nokogiri", ">= 1.4.0"
  gem "memcache-client", ">= 1.7.6"
  gem "pg", ">= 0.8.0"
end
