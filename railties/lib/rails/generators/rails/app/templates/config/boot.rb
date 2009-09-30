# Don't change this file!
# Configure your app in config/environment.rb and config/environments/*.rb

RAILS_ROOT = "#{File.dirname(__FILE__)}/.." unless defined?(RAILS_ROOT)

module Rails
  # Mark the version of Rails that generated the boot.rb file. This is
  # a temporary solution and will most likely be removed as Rails 3.0
  # comes closer.
  BOOTSTRAP_VERSION = "3.0"

  class << self
    def boot!
      unless booted?
        preinitialize
        pick_boot.run
      end
    end

    def booted?
      defined? Rails::Initializer
    end

    def pick_boot
      (vendor_rails? ? VendorBoot : GemBoot).new
    end

    def vendor_rails?
      File.exist?("#{RAILS_ROOT}/vendor/rails")
    end

    def preinitialize
      load(preinitializer_path) if File.exist?(preinitializer_path)
    end

    def preinitializer_path
      "#{RAILS_ROOT}/config/preinitializer.rb"
    end
  end

  class Boot
    def run
      load_initializer
      set_load_paths
    end

    def set_load_paths
      %w(
        railties
        railties/lib
        activesupport/lib
        actionpack/lib
        activerecord/lib
        actionmailer/lib
        activeresource/lib
        actionwebservice/lib
      ).reverse_each do |path|
        path = "#{framework_root_path}/#{path}"
        $LOAD_PATH.unshift(path) if File.directory?(path)
        $LOAD_PATH.uniq!
      end
    end

    def framework_root_path
      defined?(::RAILS_FRAMEWORK_ROOT) ? ::RAILS_FRAMEWORK_ROOT : "#{RAILS_ROOT}/vendor/rails"
    end
  end

  class VendorBoot < Boot
    def load_initializer
      $:.unshift("#{framework_root_path}/railties/lib")
      require "rails"
      install_gem_spec_stubs
      Rails::GemDependency.add_frozen_gem_path
    end

    def install_gem_spec_stubs
      begin; require "rubygems"; rescue LoadError; return; end

      %w(rails activesupport activerecord actionpack actionmailer activeresource).each do |stub|
        Gem.loaded_specs[stub] ||= Gem::Specification.new do |s|
          s.name = stub
          s.version = Rails::VERSION::STRING
          s.loaded_from = ""
        end
      end
    end
  end

  class GemBoot < Boot
    def load_initializer
      self.class.load_rubygems
      load_rails_gem
      require 'rails'
    end

    def load_rails_gem
      if version = self.class.gem_version
        gem 'rails', version
      else
        gem 'rails'
      end
    rescue Gem::LoadError => load_error
      $stderr.puts %(Missing the Rails #{version} gem. Please `gem install -v=#{version} rails`, update your RAILS_GEM_VERSION setting in config/environment.rb for the Rails version you do have installed, or comment out RAILS_GEM_VERSION to use the latest version installed.)
      exit 1
    end

    class << self
      def rubygems_version
        Gem::RubyGemsVersion rescue nil
      end

      def gem_version
        if defined? RAILS_GEM_VERSION
          RAILS_GEM_VERSION
        elsif ENV.include?('RAILS_GEM_VERSION')
          ENV['RAILS_GEM_VERSION']
        else
          parse_gem_version(read_environment_rb)
        end
      end

      def load_rubygems
        min_version = '1.3.2'
        require 'rubygems'
        unless rubygems_version >= min_version
          $stderr.puts %Q(Rails requires RubyGems >= #{min_version} (you have #{rubygems_version}). Please `gem update --system` and try again.)
          exit 1
        end

      rescue LoadError
        $stderr.puts %Q(Rails requires RubyGems >= #{min_version}. Please install RubyGems and try again: http://rubygems.rubyforge.org)
        exit 1
      end

      def parse_gem_version(text)
        $1 if text =~ /^[^#]*RAILS_GEM_VERSION\s*=\s*["']([!~<>=]*\s*[\d.]+)["']/
      end

      private
        def read_environment_rb
          File.read("#{RAILS_ROOT}/config/environment.rb")
        end
    end
  end
end

# All that for this:
Rails.boot!
