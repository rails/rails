module ActiveSupport
  module DependencyModule
    def append_features(base)
      return if base < self
      (@_dependencies ||= []).each { |dep| base.send(:include, dep) }
      super
    end

    def included(base = nil, &block)
      if base.nil? && block_given?
        @_included_block = block
      else
        base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
        base.class_eval(&@_included_block) if instance_variable_defined?("@_included_block")
      end
    end

    def depends_on(mod)
      return if self < mod
      @_dependencies ||= []
      @_dependencies << mod
    end
  end
end
