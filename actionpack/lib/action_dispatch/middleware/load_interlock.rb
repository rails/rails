require 'active_support/dependencies'
require 'rack/lock'

module ActionDispatch
  class LoadInterlock < ::Rack::Lock
    FLAG = 'activesupport.dependency_race'.freeze

    def initialize(app, mutex = ::ActiveSupport::Dependencies.interlock)
      super
    end
  end
end
