require "rails" # In case people require this file directly

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
      end
    end
  end
end