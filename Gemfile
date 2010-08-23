source 'http://rubygems.org'

if ENV['AREL']
  gem "arel", :path => ENV['AREL']
else
  gem "arel", :git => "git://github.com/rails/arel.git"
end

gem "rails", :path => File.dirname(__FILE__)

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"
gem "rdoc",  ">= 2.5.10"
gem "horo",  ">= 1.0.2"

# AS
gem "memcache-client", ">= 1.8.5"

# AM
gem "text-format", "~> 1.0.0"

platforms :mri_18 do
  gem "system_timer"
  gem "ruby-debug", ">= 0.10.3"
end

platforms :ruby do
  gem 'json'
  gem 'yajl-ruby'
  gem "nokogiri", ">= 1.4.3.1"

  # AR
  gem "sqlite3-ruby", "~> 1.3.1", :require => 'sqlite3'

  group :db do
    gem "pg", ">= 0.9.0"
    gem "mysql", ">= 2.8.1"
    gem "mysql2", ">= 0.2.3"
  end
end

platforms :jruby do
  gem "ruby-debug", ">= 0.10.3"

  gem "activerecord-jdbcsqlite3-adapter"

  group :db do
    gem "activerecord-jdbcmysql-adapter"
    gem "activerecord-jdbcpostgresql-adapter"
  end
end

# gems that are necessary for ActiveRecord tests with Oracle database
if ENV['ORACLE_ENHANCED_PATH'] || ENV['ORACLE_ENHANCED']
  platforms :ruby do
    gem 'ruby-oci8', ">= 2.0.4"
  end
  if ENV['ORACLE_ENHANCED_PATH']
    gem 'activerecord-oracle_enhanced-adapter', :path => ENV['ORACLE_ENHANCED_PATH']
  else
    gem "activerecord-oracle_enhanced-adapter", :git => "git://github.com/rsim/oracle-enhanced.git"
  end
end
