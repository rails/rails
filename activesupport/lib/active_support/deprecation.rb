# frozen_string_literal: true

require "singleton"

module ActiveSupport
  # \Deprecation specifies the API used by Rails to deprecate methods, instance
  # variables, objects, and constants.
  class Deprecation
    # active_support.rb sets an autoload for ActiveSupport::Deprecation.
    #
    # If these requires were at the top of the file the constant would not be
    # defined by the time their files were loaded. Since some of them reopen
    # ActiveSupport::Deprecation its autoload would be triggered, resulting in
    # a circular require warning for active_support/deprecation.rb.
    #
    # So, we define the constant first, and load dependencies later.
    require "active_support/deprecation/instance_delegator"
    require "active_support/deprecation/behaviors"
    require "active_support/deprecation/reporting"
    require "active_support/deprecation/disallowed"
    require "active_support/deprecation/constant_accessor"
    require "active_support/deprecation/method_wrappers"
    require "active_support/deprecation/proxy_wrappers"
    require "active_support/core_ext/module/deprecation"
    require "concurrent/atomic/thread_local_var"

    include Singleton
    include InstanceDelegator
    include Behavior
    include Reporting
    include Disallowed
    include MethodWrapper

    def self.instance
      @initialized_singleton_instance ||= super.tap do |instance|
        instance.debug = false
        instance.behavior = [:stderr]
        instance.disallowed_behavior = [:raise]
        instance.disallowed_warnings = []
        instance.default_explicitly_allowed_warnings = [].freeze
        instance.default_silenced = false
      end
    end

    # The version number in which the deprecated behavior will be removed, by default.
    attr_accessor :deprecation_horizon

    attr_accessor :default_silenced, :default_explicitly_allowed_warnings # :nodoc:

    # It accepts two parameters on initialization. The first is a version of library
    # and the second is a library name.
    #
    #   ActiveSupport::Deprecation.new('2.0', 'MyLibrary')
    def initialize(deprecation_horizon = "7.2", gem_name = "Rails")
      self.gem_name = gem_name
      self.deprecation_horizon = deprecation_horizon
      @silenced = Concurrent::ThreadLocalVar.new { default_silenced }
      @explicitly_allowed_warnings = Concurrent::ThreadLocalVar.new { default_explicitly_allowed_warnings }
    end
  end
end
