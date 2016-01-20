require 'active_support/core_ext/module/attribute_accessors_per_thread'

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
    thread_mattr_accessor :connection_handler, :sql_runtime, :connection_id
  end
end
