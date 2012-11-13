require 'singleton'

module ActiveSupport
  # \Deprecation specifies the API used by Rails to deprecate methods, instance
  # variables, objects and constants.
  class Deprecation
    # active_support.rb sets an autoload for ActiveSupport::Deprecation.
    #
    # If these requires were at the top of the file the constant would not be
    # defined by the time their files were loaded. Since some of them reopen
    # ActiveSupport::Deprecation its autoload would be triggered, resulting in
    # a circular require warning for active_support/deprecation.rb.
    #
    # So, we define the constant first, and load dependencies later.
    require 'active_support/deprecation/instance_delegator'
    require 'active_support/deprecation/behaviors'
    require 'active_support/deprecation/reporting'
    require 'active_support/deprecation/method_wrappers'
    require 'active_support/deprecation/proxy_wrappers'
    require 'active_support/core_ext/module/deprecation'

    include Singleton
    include InstanceDelegator
    include Behavior
    include Reporting
    include MethodWrapper

    # The version the deprecated behavior will be removed, by default.
    attr_accessor :deprecation_horizon

    # It accepts two parameters on initialization. The first is an version of library
    # and the second is an library name
    #
    #   ActiveSupport::Deprecation.new('2.0', 'MyLibrary')
    def initialize(deprecation_horizon = '4.1', gem_name = 'Rails')
      self.gem_name = gem_name
      self.deprecation_horizon = deprecation_horizon
      # By default, warnings are not silenced and debugging is off.
      self.silenced = false
      self.debug = false
    end
  end
end
