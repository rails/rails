module ActiveSupport
  module DependencyModule
    def setup(&blk)
      @_setup_block = blk
    end

    def append_features(base)
      return if base < self
      (@_dependencies ||= []).each { |dep| base.send(:include, dep) }
      super
    end

    def included(base)
      base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
      base.class_eval(&@_setup_block) if instance_variable_defined?("@_setup_block")
    end

    def depends_on(mod)
      return if self < mod
      @_dependencies ||= []
      @_dependencies << mod
    end
  end
end
