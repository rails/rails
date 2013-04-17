require 'active_support/per_thread_registry'

module ActiveRecord
  # This is a thread locals registry for Active Record. For example:
  #
  #   ActiveRecord::RuntimeRegistry.connection_handler
  #
  # returns the connection handler local to the current thread.
  #
  # See the documentation of <tt>ActiveSupport::PerThreadRegistry</tt>
  # for further details.
  class RuntimeRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :connection_handler, :sql_runtime, :connection_id
  end
end
