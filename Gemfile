source 'https://rubygems.org'

ruby "~> #{RUBY_VERSION}" if ENV["TRAVIS"]

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gemspec

# We need a newish Rake since Active Job sets its test tasks' descriptions.
gem 'rake', '>= 10.3'

# This needs to be with require false as it is
# loaded after loading the test library to
# ensure correct loading order
gem 'mocha', '~> 0.14', require: false

gem 'rack-cache', '~> 1.2'
gem 'jquery-rails', '~> 4.0'
gem 'coffee-rails', '~> 4.1.0'

if RUBY_VERSION < "2.1"
  gem 'turbolinks', '< 5.1'
else
  gem 'turbolinks'
end

gem 'sprockets', '~> 3.0.0.rc.1'
gem 'execjs', '< 2.5'

# require: false so bcrypt is loaded only when has_secure_password is used.
# This is to avoid ActiveModel (and by extension the entire framework)
# being dependent on a binary library.
gem 'bcrypt', '~> 3.1.10', require: false

# This needs to be with require false to avoid
# it being automatically loaded by sprockets
gem 'uglifier', '>= 1.3.0', "< 4.0.0", require: false

# mime-types 3 only support ruby >= 2
gem 'mime-types', '< 3', require: false

group :doc do
  gem 'sdoc', '~> 0.4.0'
  gem 'redcarpet', '~> 3.1.2', platforms: :ruby
  gem 'w3c_validators', RUBY_VERSION < '2.0' ? '1.2' : nil
  gem 'kindlerb', '0.1.1'
  gem 'mustache', '~> 0.99.8'
end

# AS
gem 'dalli', '< 2.7.7'

# ActiveJob
group :job do
  gem 'resque', require: false
  gem 'resque-scheduler', RUBY_VERSION < '2.0' ? '<= 4.3.0' : nil
  gem 'sidekiq', RUBY_VERSION < '2.2' ? '< 5' : nil, require: false
  gem 'sucker_punch', '< 2.0', require: false
  gem 'delayed_job', require: false
  gem 'queue_classic', '> 0.3.2', require: false, platforms: :ruby
  gem 'sneakers', '< 2.0.0', require: false
  gem 'que', require: false
  gem 'backburner', require: false
  gem 'qu-rails', github: "bkeepers/qu", branch: "master", require: false
  gem 'qu-redis', require: false
  gem 'delayed_job_active_record', require: false
  gem 'sequel', require: false
  gem 'amq-protocol', '< 2.0.0', require: false
end

# Add your own local bundler stuff
local_gemfile = File.dirname(__FILE__) + "/.Gemfile"
instance_eval File.read local_gemfile if File.exist? local_gemfile

group :test do
  # FIX: Our test suite isn't ready to run in random order yet
  gem 'minitest', '< 5.3.4'

  platforms :mri_19 do
    gem 'ruby-prof', '~> 0.11.2'
  end

  # platforms :mri_19, :mri_20 do
  #   gem 'debugger'
  # end

  platforms :mri_21 do
    gem 'stackprof'
  end

  gem 'benchmark-ips'
end

platforms :ruby do
  gem 'nokogiri', RUBY_VERSION < '2.1' ? '~> 1.6.0' : '>= 1.7'

  # Needed for compiling the ActionDispatch::Journey parser
  gem 'racc', '>=1.4.6', require: false

  # AR
  gem 'sqlite3', '~> 1.3.6'

  group :db do
    gem 'pg', '>= 0.15.0'
    gem 'mysql2', RUBY_VERSION < '2.0' ? '~> 0.4.0' : '>= 0.4.0'
  end
end

platforms :mri_19, :mri_20, :mri_21, :mri_22, :mri_23 do
  group :db do
    gem 'mysql', '>= 2.9.0'
  end
end

platforms :jruby do
  if ENV['AR_JDBC']
    gem 'activerecord-jdbcsqlite3-adapter', github: 'jruby/activerecord-jdbc-adapter', branch: 'master'
    group :db do
      gem 'activerecord-jdbcmysql-adapter', github: 'jruby/activerecord-jdbc-adapter', branch: 'master'
      gem 'activerecord-jdbcpostgresql-adapter', github: 'jruby/activerecord-jdbc-adapter', branch: 'master'
    end
  else
    gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0'
    group :db do
      gem 'activerecord-jdbcmysql-adapter', '>= 1.3.0'
      gem 'activerecord-jdbcpostgresql-adapter', '>= 1.3.0'
    end
  end
end

platforms :rbx do
  # The rubysl-yaml gem doesn't ship with Psych by default
  # as it needs libyaml that isn't always available.
  gem 'psych', '~> 2.0'
end

# gems that are necessary for ActiveRecord tests with Oracle database
if ENV['ORACLE_ENHANCED']
  platforms :ruby do
    gem 'ruby-oci8', '~> 2.1'
  end
  gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'master'
end

# A gem necessary for ActiveRecord tests with IBM DB
gem 'ibm_db' if ENV['IBM_DB']
