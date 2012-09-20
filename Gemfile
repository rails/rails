source 'https://rubygems.org'

gemspec

gem 'arel', github: 'rails/arel', branch: 'master'

gem 'mocha', '>= 0.11.2', :require => false
gem 'rack-test', github: 'brynary/rack-test'
gem 'bcrypt-ruby', '~> 3.0.0'
gem 'jquery-rails'

gem 'journey', github: 'rails/journey', branch: 'master'

gem 'activerecord-deprecated_finders', github: 'rails/activerecord-deprecated_finders', branch: 'master'

# This needs to be with require false to avoid
# it being automatically loaded by sprockets
gem 'uglifier', require: false

gem 'sprockets-rails', github: 'rails/sprockets-rails', branch: 'master'

group :doc do
  # The current sdoc cannot generate GitHub links due
  # to a bug, but the PR that fixes it has been there
  # for some weeks unapplied. As a temporary solution
  # this is our own fork with the fix.
  gem 'sdoc',  github: 'fxn/sdoc'
  gem 'redcarpet', '~> 2.1.1'
  gem 'w3c_validators'
end

# AS
gem 'dalli', '>= 2.2.1'

# Add your own local bundler stuff
local_gemfile = File.dirname(__FILE__) + "/.Gemfile"
instance_eval File.read local_gemfile if File.exists? local_gemfile

platforms :mri do
  group :test do
    gem 'ruby-prof', '~> 0.11.2'
  end
end

platforms :ruby do
  gem 'json'
  gem 'yajl-ruby'
  gem 'nokogiri', '>= 1.4.5'

  # AR
  gem 'sqlite3', '~> 1.3.6'

  group :db do
    gem 'pg', '>= 0.11.0'
    gem 'mysql', '>= 2.8.1' if RUBY_VERSION < '2.0.0'
    gem 'mysql2', '>= 0.3.10'
  end
end

platforms :jruby do
  gem 'json'
  gem 'activerecord-jdbcsqlite3-adapter', '>= 1.2.0'

  # This is needed by now to let tests work on JRuby
  # TODO: When the JRuby guys merge jruby-openssl in
  # jruby this will be removed
  gem 'jruby-openssl'

  group :db do
    gem 'activerecord-jdbcmysql-adapter', '>= 1.2.0'
    gem 'activerecord-jdbcpostgresql-adapter', '>= 1.2.0'
  end
end

# gems that are necessary for ActiveRecord tests with Oracle database
if ENV['ORACLE_ENHANCED']
  platforms :ruby do
    gem 'ruby-oci8', '>= 2.0.4'
  end
  gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'master'
end

# A gem necessary for ActiveRecord tests with IBM DB
gem 'ibm_db' if ENV['IBM_DB']

gem 'benchmark-ips'
