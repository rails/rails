module ActiveRecord::Associations::Builder
  class CollectionAssociation < Association #:nodoc:
    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove]

    def valid_options
      super + [:table_name, :finder_sql, :counter_sql, :before_add, :after_add, :before_remove, :after_remove]
    end

    attr_reader :block_extension, :extension_module

    def initialize(*args, &extension)
      super(*args)
      @block_extension = extension
    end

    def build
      wrap_block_extension
      reflection = super
      CALLBACKS.each { |callback_name| define_callback(callback_name) }
      reflection
    end

    def writable?
      true
    end

    private

      def wrap_block_extension
        if block_extension
          @extension_module = mod = Module.new(&block_extension)
          silence_warnings do
            model.parent.const_set(extension_module_name, mod)
          end

          prev_scope = @scope

          if prev_scope
            @scope = proc { |owner| instance_exec(owner, &prev_scope).extending(mod) }
          else
            @scope = proc { extending(mod) }
          end
        end
      end

      def extension_module_name
        @extension_module_name ||= "#{model.name.demodulize}#{name.to_s.camelize}AssociationExtension"
      end

      def define_callback(callback_name)
        full_callback_name = "#{callback_name}_for_#{name}"

        # TODO : why do i need method_defined? I think its because of the inheritance chain
        model.class_attribute full_callback_name.to_sym unless model.method_defined?(full_callback_name)
        model.send("#{full_callback_name}=", Array(options[callback_name.to_sym]))
      end

      def define_readers
        super

        name = self.name
        mixin.redefine_method("#{name.to_s.singularize}_ids") do
          association(name).ids_reader
        end
      end

      def define_writers
        super

        name = self.name
        mixin.redefine_method("#{name.to_s.singularize}_ids=") do |ids|
          association(name).ids_writer(ids)
        end
      end
  end
end
