require "pathname"

require 'rails/initializable'
require 'rails/application'
require 'rails/railties_path'
require 'rails/version'
require 'rails/gem_dependency'
require 'rails/rack'
require 'rails/paths'
require 'rails/core'
require 'rails/configuration'

RAILS_ENV = (ENV['RAILS_ENV'] || 'development').dup unless defined?(RAILS_ENV)

module Rails
  class Initializer
    class Error < StandardError ; end
    def self.run(initializer = nil, config = nil)
      if initializer
        # Deprecated
      else
        Rails.application = Class.new(Application)
        yield Rails.application.config if block_given?
        Rails.application.new
      end
    end
  end
end
