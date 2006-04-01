# Don't change this file. Configuration is done in config/environment.rb and config/environments/*.rb

unless defined?(RAILS_ROOT)
  root_path = File.join(File.dirname(__FILE__), '..')
  unless RUBY_PLATFORM =~ /mswin32/
    require 'pathname'
    root_path = Pathname.new(root_path).cleanpath(true).to_s
  end
  RAILS_ROOT = root_path
end

if File.directory?("#{RAILS_ROOT}/vendor/rails")
  require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
else
  require 'rubygems'

  if !defined?(RAILS_GEM_VERSION) && File.read(File.dirname(__FILE__) + '/environment.rb') =~ /RAILS_GEM_VERSION = '([\d.]+)'/
    RAILS_GEM_VERSION = $1
  end

  if defined?(RAILS_GEM_VERSION)
    rails_gem = Gem.cache.search('rails', "=#{RAILS_GEM_VERSION}").first

    if rails_gem
      require rails_gem.full_gem_path + '/lib/initializer'
    else
      STDERR.puts %(Cannot find gem for Rails =#{RAILS_GEM_VERSION}:
  Install the missing gem with 'gem install -v=#{RAILS_GEM_VERSION} rails', or
  change environment.rb to define RAILS_GEM_VERSION with your desired version.
)
      exit 1
    end
  else
    require 'initializer'
  end
end

Rails::Initializer.run(:set_load_path)