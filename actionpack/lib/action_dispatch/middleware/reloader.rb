# frozen_string_literal: true

module ActionDispatch
  # ActionDispatch::Reloader wraps the request with callbacks provided by
  # ActiveSupport::Reloader, intended to assist with code reloading during
  # development.
  #
  # ActionDispatch::Reloader is included in the middleware stack only if
  # reloading is enabled, which it is by the default in +development+ mode.
  class Reloader < Executor
  end
end
