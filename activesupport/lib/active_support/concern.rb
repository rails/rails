# A typical module looks like this
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
module ActiveSupport
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
