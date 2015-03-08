require 'active_support'

module Rails
  class << self
    # Returns the current Rails environment.
    #
    #   Rails.env # => 'development'
    #   Rails.env.development? # => true
    #   Rails.env.production? # => false
    def env
      @_env ||= env_factory
    end

    # Sets the Rails environment and synchronizes RAILS_ENV.
    #
    #   Rails.env = 'staging' # => 'staging'
    def env=(environment)
      if @_env != environment
        ENV['RAILS_ENV'] = @_env = env_factory(environment)
      end
      @_env
    end

    private

    def env_factory(environment = nil)
      ActiveSupport::StringInquirer.new(environment || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || DEFAULT_ENV)
    end

    DEFAULT_ENV = 'development'.freeze
  end
end
