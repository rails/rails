# frozen_string_literal: true

module ActionDispatch
  # ActionDispatch::Reloader wraps the request with callbacks provided by ActiveSupport::Reloader
  # callbacks, intended to assist with code reloading during development.
  #
  # By default, ActionDispatch::Reloader is included in the middleware stack
  # only in the development environment; specifically, when +config.cache_classes+
  # is false.
  class Reloader < Executor
  end
end
