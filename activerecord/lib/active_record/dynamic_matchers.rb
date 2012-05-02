module ActiveRecord
  module DynamicMatchers
    def respond_to?(name, include_private = false)
      match = Method.match(self, name)
      match && match.valid? || super
    end

    private

    # Enables dynamic finders like <tt>User.find_by_user_name(user_name)</tt> and
    # <tt>User.scoped_by_user_name(user_name). Refer to Dynamic attribute-based finders
    # section at the top of this file for more detailed information.
    #
    # It's even possible to use all the additional parameters to +find+. For example, the
    # full interface for +find_all_by_amount+ is actually <tt>find_all_by_amount(amount, options)</tt>.
    #
    # Each dynamic finder using <tt>scoped_by_*</tt> is also defined in the class after it
    # is first invoked, so that future attempts to use it do not run through method_missing.
    def method_missing(name, *arguments, &block)
      match = Method.match(self, name)

      if match && match.valid?
        match.define
        send(name, *arguments, &block)
      else
        super
      end
    end

    class Method
      def self.match(model, name)
        klass = klasses.find { |k| name =~ k.pattern }
        klass.new(model, name) if klass
      end

      def self.klasses
        [
          FindBy, FindAllBy, FindLastBy, FindByBang, ScopedBy,
          FindOrInitializeBy, FindOrCreateBy, FindOrCreateByBang
        ]
      end

      def self.pattern
        /^#{prefix}_([_a-zA-Z]\w*)#{suffix}$/
      end

      def self.prefix
        raise NotImplementedError
      end

      def self.suffix
        ''
      end

      attr_reader :model, :name, :attribute_names

      def initialize(model, name)
        @model           = model
        @name            = name.to_s
        @attribute_names = @name.match(self.class.pattern)[1].split('_and_')
      end

      def expand_attribute_names_for_aggregates
        attribute_names.map do |attribute_name|
          if aggregation = model.reflect_on_aggregation(attribute_name.to_sym)
            model.send(:aggregate_mapping, aggregation).map do |field_attr, _|
              field_attr.to_sym
            end
          else
            attribute_name.to_sym
          end
        end.flatten
      end

      def valid?
        (expand_attribute_names_for_aggregates - model.column_methods_hash.keys).empty?
      end

      def define
        model.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def self.#{name}(#{signature})
            #{body}
          end
        CODE
      end

      def body
        raise NotImplementedError
      end
    end

    class Finder < Method
      def body
        <<-CODE
          result = #{result}
          result && block_given? ? yield(result) : result
        CODE
      end

      def result
        "scoped.apply_finder_options(options).#{finder}(#{attributes_hash})"
      end

      def signature
        attribute_names.join(', ') + ", options = {}"
      end

      def attributes_hash
        "{" + attribute_names.map { |name| ":#{name} => #{name}" }.join(',') + "}"
      end

      def finder
        raise NotImplementedError
      end
    end

    class FindBy < Finder
      def self.prefix
        "find_by"
      end

      def finder
        "find_by"
      end
    end

    class FindByBang < Finder
      def self.prefix
        "find_by"
      end

      def self.suffix
        "!"
      end

      def finder
        "find_by!"
      end
    end

    class FindAllBy < Finder
      def self.prefix
        "find_all_by"
      end

      def finder
        "where"
      end

      def result
        "#{super}.to_a"
      end
    end

    class FindLastBy < Finder
      def self.prefix
        "find_last_by"
      end

      def finder
        "where"
      end

      def result
        "#{super}.last"
      end
    end

    class ScopedBy < Finder
      def self.prefix
        "scoped_by"
      end

      def body
        "where(#{attributes_hash})"
      end
    end

    class Instantiator < Method
      # This is nasty, but it doesn't matter because it will be deprecated.
      def self.dispatch(klass, attribute_names, instantiator, args, block)
        if args.length == 1 && args.first.is_a?(Hash)
          attributes = args.first.stringify_keys
          conditions = attributes.slice(*attribute_names)
          rest       = [attributes.except(*attribute_names)]
        else
          raise ArgumentError, "too few arguments" unless args.length >= attribute_names.length

          conditions = Hash[attribute_names.map.with_index { |n, i| [n, args[i]] }]
          rest       = args.drop(attribute_names.length)
        end

        klass.where(conditions).first ||
          klass.create_with(conditions).send(instantiator, *rest, &block)
      end

      def signature
        "*args, &block"
      end

      def body
        "#{self.class}.dispatch(self, #{attribute_names.inspect}, #{instantiator.inspect}, args, block)"
      end

      def instantiator
        raise NotImplementedError
      end
    end

    class FindOrInitializeBy < Instantiator
      def self.prefix
        "find_or_initialize_by"
      end

      def instantiator
        "new"
      end
    end

    class FindOrCreateBy < Instantiator
      def self.prefix
        "find_or_create_by"
      end

      def instantiator
        "create"
      end
    end

    class FindOrCreateByBang < Instantiator
      def self.prefix
        "find_or_create_by"
      end

      def self.suffix
        "!"
      end

      def instantiator
        "create!"
      end
    end

    def aggregate_mapping(reflection)
      mapping = reflection.options[:mapping] || [reflection.name, reflection.name]
      mapping.first.is_a?(Array) ? mapping : [mapping]
    end
  end
end
