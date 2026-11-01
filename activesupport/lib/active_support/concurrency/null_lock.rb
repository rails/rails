# frozen_string_literal: true

module ActiveSupport
  module Concurrency
    module NullLock # :nodoc:
      extend self

      def synchronize
        yield
      end
    end
  end
end
