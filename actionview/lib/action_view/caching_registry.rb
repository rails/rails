# frozen_string_literal: true

module ActionView
  # = Action View Caching registry
  class CachingRegistry #:nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :is_caching
  end
end