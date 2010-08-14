module ActiveSupport
  # A typical module looks like this:
  #
  #   module M
  #     def self.included(base)
  #       base.send(:extend, ClassMethods)
  #       base.send(:include, InstanceMethods)
  #       scope :foo, :conditions => { :created_at => nil }
  #     end
  #
  #     module ClassMethods
  #       def cm; puts 'I am a class method'; end
  #     end
  #
  #     module InstanceMethods
  #       def im; puts 'I am an instance method'; end
  #     end
  #   end
  #
  # By using <tt>ActiveSupport::Concern</tt> the above module could instead be written as:
  #   
  #   require 'active_support/concern'
  #
  #   module M
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       scope :foo, :conditions => { :created_at => nil }
  #     end
  #
  #     module ClassMethods
  #       def cm; puts 'I am a class method'; end
  #     end
  #
  #     module InstanceMethods
  #       def im; puts 'I am an instance method'; end
  #     end
  #   end
  #
  # Moreover, it gracefully handles module dependencies. Given a Foo module and a Bar module which depends on the former, we would typically write the following:
  #
  #   module Foo
  #     def self.included(base)
  #       # Define some :enhanced_method for Host class
  #       base.class_eval do
  #         def self.enhanced_method
  #           # Do enhanced stuff
  #         end
  #       end
  #     end
  #   end
  #
  #   module Bar
  #     def self.included(base)
  #       base.send(:enhanced_method)
  #     end
  #   end
  #
  #   class Host
  #     include Foo # We need to include this dependency for Bar
  #     include Bar # Bar is the module that Host really needs
  #   end
  #
  # But why should Host care about Bar's dependencies, namely Foo? We could try to hide these from Host directly including Foo in Bar:
  #
  #   module Foo
  #     def self.included(base)
  #       # Define some :enhanced_method for Host class
  #       base.class_eval do
  #         def self.enhanced_method
  #           # Do enhanced stuff
  #         end
  #       end
  #     end
  #   end
  #
  #   module Bar
  #     include Foo 
  #     def self.included(base)
  #       base.send(:enhanced_method)
  #     end
  #   end
  #
  #   class Host
  #     include Bar
  #   end
  #
  # Unfortunately this won't work, since when Foo is included, its <tt>base</tt> is Bar module, not Host class.
  # With <tt>ActiveSupport::Concern</tt>, module dependencies are properly resolved:
  #
  #   require 'active_support/concern'
  #
  #   module Foo
  #     extend ActiveSupport::Concern
  #     included do
  #       class_eval do
  #         def self.enhanced_method
  #           # Do enhanced stuff
  #         end
  #       end
  #     end
  #   end
  #
  #   module Bar
  #     extend ActiveSupport::Concern
  #     include Foo
  #
  #     included do
  #       self.send(:enhanced_method)
  #     end
  #   end
  #
  #   class Host
  #     include Bar # Host only needs to care about Bar without needing to know about its dependencies
  #   end
  #
  module Concern
    def self.extended(base)
      base.instance_variable_set("@_dependencies", [])
    end

    def append_features(base)
      if base.instance_variable_defined?("@_dependencies")
        base.instance_variable_get("@_dependencies") << self
        return false
      else
        return false if base < self
        @_dependencies.each { |dep| base.send(:include, dep) }
        super
        base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
        base.send :include, const_get("InstanceMethods") if const_defined?("InstanceMethods")
        base.class_eval(&@_included_block) if instance_variable_defined?("@_included_block")
      end
    end

    def included(base = nil, &block)
      if base.nil?
        @_included_block = block
      else
        super
      end
    end
  end
end
