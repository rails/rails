module ActiveRecord::Associations::Builder # :nodoc:
  class HasAndBelongsToMany # :nodoc:
    class JoinTableResolver # :nodoc:
      KnownTable = Struct.new :join_table

      class KnownClass # :nodoc:
        def initialize(lhs_class, rhs_class_name)
          @lhs_class      = lhs_class
          @rhs_class_name = rhs_class_name
          @join_table     = nil
        end

        def join_table
          @join_table ||= [@lhs_class.table_name, klass.table_name].sort.join("\0").gsub(/^(.*[._])(.+)\0\1(.+)/, '\1\2_\3').tr("\0", "_")
        end

        private

          def klass
            @lhs_class.send(:compute_type, @rhs_class_name)
          end
      end

      def self.build(lhs_class, name, options)
        if options[:join_table]
          KnownTable.new options[:join_table].to_s
        else
          class_name = options.fetch(:class_name) {
            name.to_s.camelize.singularize
          }
          KnownClass.new lhs_class, class_name
        end
      end
    end

    attr_reader :lhs_model, :association_name, :options

    def initialize(association_name, lhs_model, options)
      @association_name = association_name
      @lhs_model = lhs_model
      @options = options
    end

    def through_model
      habtm = JoinTableResolver.build lhs_model, association_name, options

      join_model = Class.new(ActiveRecord::Base) {
        class << self;
          attr_accessor :left_model
          attr_accessor :name
          attr_accessor :table_name_resolver
          attr_accessor :left_reflection
          attr_accessor :right_reflection
        end

        def self.table_name
          table_name_resolver.join_table
        end

        def self.compute_type(class_name)
          left_model.compute_type class_name
        end

        def self.add_left_association(name, options)
          belongs_to name, required: false, **options
          self.left_reflection = _reflect_on_association(name)
        end

        def self.add_right_association(name, options)
          rhs_name = name.to_s.singularize.to_sym
          belongs_to rhs_name, required: false, **options
          self.right_reflection = _reflect_on_association(rhs_name)
        end

        def self.retrieve_connection
          left_model.retrieve_connection
        end

        private

        def self.suppress_composite_primary_key(pk)
          pk unless pk.is_a?(Array)
        end
      }

      join_model.name                = "HABTM_#{association_name.to_s.camelize}"
      join_model.table_name_resolver = habtm
      join_model.left_model          = lhs_model

      join_model.add_left_association :left_side, anonymous_class: lhs_model
      join_model.add_right_association association_name, belongs_to_options(options)
      join_model
    end

    def middle_reflection(join_model)
      middle_name = [lhs_model.name.downcase.pluralize,
                     association_name].join("_".freeze).gsub("::".freeze, "_".freeze).to_sym
      middle_options = middle_options join_model

      HasMany.create_reflection(lhs_model,
                                middle_name,
                                nil,
                                middle_options)
    end

    private

      def middle_options(join_model)
        middle_options = {}
        middle_options[:class_name] = "#{lhs_model.name}::#{join_model.name}"
        middle_options[:source] = join_model.left_reflection.name
        if options.key? :foreign_key
          middle_options[:foreign_key] = options[:foreign_key]
        end
        middle_options
      end

      def belongs_to_options(options)
        rhs_options = {}

        if options.key? :class_name
          rhs_options[:foreign_key] = options[:class_name].to_s.foreign_key
          rhs_options[:class_name] = options[:class_name]
        end

        if options.key? :association_foreign_key
          rhs_options[:foreign_key] = options[:association_foreign_key]
        end

        rhs_options
      end
  end
end
