module ActiveRecord::Associations::Builder
  class CollectionAssociation < Association #:nodoc:
    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove]

    self.valid_options += [
      :table_name, :order, :group, :having, :limit, :offset, :uniq, :finder_sql,
      :counter_sql, :before_add, :after_add, :before_remove, :after_remove
    ]

    attr_reader :block_extension

    def self.build(model, name, options, &extension)
      new(model, name, options, &extension).build
    end

    def initialize(model, name, options, &extension)
      super(model, name, options)
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
        options[:extend] = Array.wrap(options[:extend])

        if block_extension
          silence_warnings do
            model.parent.const_set(extension_module_name, Module.new(&block_extension))
          end
          options[:extend].push("#{model.parent}::#{extension_module_name}".constantize)
        end
      end

      def extension_module_name
        @extension_module_name ||= "#{model.to_s.demodulize}#{name.to_s.camelize}AssociationExtension"
      end

      def define_callback(callback_name)
        full_callback_name = "#{callback_name}_for_#{name}"

        # TODO : why do i need method_defined? I think its because of the inheritance chain
        model.class_attribute full_callback_name.to_sym unless model.method_defined?(full_callback_name)
        model.send("#{full_callback_name}=", Array.wrap(options[callback_name.to_sym]))
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
