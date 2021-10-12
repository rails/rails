# frozen_string_literal: true

require "active_support/per_thread_registry"

module ActiveRecord
  # This is a thread locals registry for Active Record. For example:
  #
  #   ActiveRecord::RuntimeRegistry.connection_handler
  #
  # returns the connection handler local to the current thread.
  #
  # See the documentation of ActiveSupport::PerThreadRegistry
  # for further details.
  class RuntimeRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :sql_runtime

    def self.sql_runtime; instance.sql_runtime; end
    def self.sql_runtime=(x); instance.sql_runtime = x; end
  end
end
