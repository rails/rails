class Object
  def remove_subclasses_of(*superclasses) #:nodoc:
    Class.remove_class(*subclasses_of(*superclasses))
  end

  begin
    ObjectSpace.each_object(Class.new) {}

    # Exclude this class unless it's a subclass of our supers and is defined.
    # We check defined? in case we find a removed class that has yet to be
    # garbage collected. This also fails for anonymous classes -- please
    # submit a patch if you have a workaround.
    def subclasses_of(*superclasses) #:nodoc:
      subclasses = []

      superclasses.each do |sup|
        ObjectSpace.each_object(class << sup; self; end) do |k|
          if k != sup && (k.name.blank? || eval("defined?(::#{k}) && ::#{k}.object_id == k.object_id"))
            subclasses << k
          end
        end
      end

      subclasses
    end
  rescue RuntimeError
    # JRuby and any implementations which cannot handle the objectspace traversal
    # above fall back to this implementation
    def subclasses_of(*superclasses) #:nodoc:
      subclasses = []

      superclasses.each do |sup|
        ObjectSpace.each_object(Class) do |k|
          if superclasses.any? { |superclass| k < superclass } &&
            (k.name.blank? || eval("defined?(::#{k}) && ::#{k}.object_id == k.object_id"))
            subclasses << k
          end
        end
        subclasses.uniq!
      end
      subclasses
    end
  end

  def extended_by #:nodoc:
    ancestors = class << self; ancestors end
    ancestors.select { |mod| mod.class == Module } - [ Object, Kernel ]
  end

  def extend_with_included_modules_from(object) #:nodoc:
    object.extended_by.each { |mod| extend mod }
  end

  unless defined? instance_exec # 1.9
    module InstanceExecMethods #:nodoc:
    end
    include InstanceExecMethods

    # Evaluate the block with the given arguments within the context of
    # this object, so self is set to the method receiver.
    #
    # From Mauricio's http://eigenclass.org/hiki/bounded+space+instance_exec
    def instance_exec(*args, &block)
      begin
        old_critical, Thread.critical = Thread.critical, true
        n = 0
        n += 1 while respond_to?(method_name = "__instance_exec#{n}")
        InstanceExecMethods.module_eval { define_method(method_name, &block) }
      ensure
        Thread.critical = old_critical
      end

      begin
        send(method_name, *args)
      ensure
        InstanceExecMethods.module_eval { remove_method(method_name) } rescue nil
      end
    end
  end
end
