# frozen_string_literal: true

module ActiveSupport
  # = Active Support \Deprecation
  #
  # \Deprecation specifies the API used by \Rails to deprecate methods, instance variables, objects, and constants. It's
  # also available for gems or applications.
  #
  # For a gem, use Deprecation.new to create a Deprecation object and store it in your module or class (in order for
  # users to be able to configure it).
  #
  #   module MyLibrary
  #     def self.deprecator
  #       @deprecator ||= ActiveSupport::Deprecation.new("2.0", "MyLibrary")
  #     end
  #   end
  #
  # For a Railtie or Engine, you may also want to add it to the application's deprecators, so that the application's
  # configuration can be applied to it.
  #
  #   module MyLibrary
  #     class Railtie < Rails::Railtie
  #       initializer "my_library.deprecator" do |app|
  #         app.deprecators[:my_library] = MyLibrary.deprecator
  #       end
  #     end
  #   end
  #
  # With the above initializer, configuration settings like the following will affect +MyLibrary.deprecator+:
  #
  #   # in config/environments/test.rb
  #   config.active_support.deprecation = :raise
  class Deprecation
    # active_support.rb sets an autoload for ActiveSupport::Deprecation.
    #
    # If these requires were at the top of the file the constant would not be
    # defined by the time their files were loaded. Since some of them reopen
    # ActiveSupport::Deprecation its autoload would be triggered, resulting in
    # a circular require warning for active_support/deprecation.rb.
    #
    # So, we define the constant first, and load dependencies later.
    require "active_support/deprecation/behaviors"
    require "active_support/deprecation/reporting"
    require "active_support/deprecation/disallowed"
    require "active_support/deprecation/constant_accessor"
    require "active_support/deprecation/method_wrappers"
    require "active_support/deprecation/proxy_wrappers"
    require "active_support/deprecation/deprecators"
    require "active_support/core_ext/module/deprecation"
    require "concurrent/atomic/thread_local_var"

    include Behavior
    include Reporting
    include Disallowed
    include MethodWrapper

    MUTEX = Mutex.new # :nodoc:
    private_constant :MUTEX

    def self._instance # :nodoc:
      @_instance ||= MUTEX.synchronize { @_instance ||= new }
    end

    # The version number in which the deprecated behavior will be removed, by default.
    attr_accessor :deprecation_horizon

    # It accepts two parameters on initialization. The first is a version of library
    # and the second is a library name.
    #
    #   ActiveSupport::Deprecation.new('2.0', 'MyLibrary')
    def initialize(deprecation_horizon = "8.1", gem_name = "Rails")
      self.gem_name = gem_name
      self.deprecation_horizon = deprecation_horizon
      # By default, warnings are not silenced and debugging is off.
      self.silenced = false
      self.debug = false
      @silence_counter = Concurrent::ThreadLocalVar.new(0)
      @explicitly_allowed_warnings = Concurrent::ThreadLocalVar.new(nil)
    end
  end
end
