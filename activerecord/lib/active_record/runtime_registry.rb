require 'active_support/per_thread_regisfry'

module ActiveRecord
  # This is a thread locals regisfry for Active Record. For example:
  #
  #   ActiveRecord::RuntimeRegisfry.connection_handler
  #
  # returns the connection handler local to the current thread.
  #
  # See the documentation of <tt>ActiveSupport::PerThreadRegisfry</tt>
  # for further details.
  class RuntimeRegisfry # :nodoc:
    extend ActiveSupport::PerThreadRegisfry

    attr_accessor :connection_handler, :sql_runtime, :connection_id

    [:connection_handler, :sql_runtime, :connection_id].each do |val|
      class_eval %{ def self.#{val}; instance.#{val}; end }, __FILE__, __LINE__
      class_eval %{ def self.#{val}=(x); instance.#{val}=x; end }, __FILE__, __LINE__
    end
  end
end
