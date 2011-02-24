source 'http://rubygems.org'

gemspec

if ENV['AREL']
  gem "arel", :path => ENV['AREL']
else
  gem "arel", :git => "git://github.com/rails/arel.git"
end

gem "rack", :git => "git://github.com/rack/rack.git"
gem "rack-test", :git => "git://github.com/brynary/rack-test.git"

gem "rake",  ">= 0.8.7"
gem "mocha", ">= 0.9.8"

group :doc do
  gem "rdoc",  "~> 3.4"
  gem "horo",  "= 1.0.3"
  gem "RedCloth", "~> 4.2" if RUBY_VERSION < "1.9.3"
end

# AS
gem "memcache-client", ">= 1.8.5"
gem "fssm", "~> 0.2.5"

platforms :mri_18 do
  gem "system_timer"
  gem "ruby-debug", ">= 0.10.3"
  gem 'ruby-prof'
end

platforms :mri_19 do
  # TODO: Remove the conditional when ruby-debug19 supports Ruby >= 1.9.3
  gem "ruby-debug19", :require => 'ruby-debug' if RUBY_VERSION < "1.9.3"
end

platforms :ruby do
  gem 'json'
  gem 'yajl-ruby'
  gem "nokogiri", ">= 1.4.4"

  # AR
  gem "sqlite3", "~> 1.3.3"

  group :db do
    gem "pg", ">= 0.9.0"
    gem "mysql", ">= 2.8.1"
    gem "mysql2", :git => "git://github.com/brianmario/mysql2.git"
  end
end

platforms :jruby do
  gem "ruby-debug", ">= 0.10.3"

  gem "activerecord-jdbcsqlite3-adapter"

  # This is needed by now to let tests work on JRuby
  # TODO: When the JRuby guys merge jruby-openssl in
  # jruby this will be removed
  gem "jruby-openssl"

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
