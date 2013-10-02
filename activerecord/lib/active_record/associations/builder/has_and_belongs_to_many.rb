module ActiveRecord::Associations::Builder
  class HABTM
    class JoinTableResolver
      KnownTable = Struct.new :join_table

      class KnownClass
        def initialize(rhs_class, lhs_class_name)
          @rhs_class      = rhs_class
          @lhs_class_name = lhs_class_name
          @join_table     = nil
        end

        def join_table
          @join_table ||= [@rhs_class.table_name, klass.table_name].sort.join("\0").gsub(/^(.*_)(.+)\0\1(.+)/, '\1\2_\3').gsub("\0", "_")
        end

        private
        def klass; @lhs_class_name.constantize; end
      end

      def self.build(rhs_class, name, options)
        if options[:join_table]
          KnownTable.new options[:join_table]
        else
          class_name = options.fetch(:class_name) {
            name.to_s.camelize.singularize
          }
          KnownClass.new rhs_class, class_name
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
          attr_accessor :class_resolver
          attr_accessor :name
          attr_accessor :table_name_resolver
          attr_accessor :left_association_name
          attr_accessor :right_association_name
        end

        def self.table_name
          table_name_resolver.join_table
        end

        def self.compute_type(class_name)
          class_resolver.compute_type class_name
        end

        def self.add_left_association(name, options)
          self.left_association_name = name
          belongs_to name, options
        end

        def self.add_right_association(name, options)
          rhs_name = name.to_s.singularize.to_sym
          self.right_association_name = rhs_name
          belongs_to rhs_name, options
        end

      }

      join_model.name                = "HABTM_#{association_name.to_s.camelize}"
      join_model.table_name_resolver = habtm
      join_model.class_resolver      = lhs_model

      join_model.add_left_association :left_side, class: lhs_model
      join_model.add_right_association association_name, belongs_to_options(options)
      join_model
    end

    def middle_options(join_model)
      middle_options = {}
      middle_options[:class] = join_model
      middle_options[:source] = join_model.left_association_name
      if options.key? :foreign_key
        middle_options[:foreign_key] = options[:foreign_key]
      end
      middle_options
    end

    private

    def belongs_to_options(options)
      rhs_options = {}

      if options.key? :class_name
        rhs_options[:foreign_key] = options[:class_name].foreign_key
        rhs_options[:class_name] = options[:class_name]
      end

      if options.key? :association_foreign_key
        rhs_options[:foreign_key] = options[:association_foreign_key]
      end

      rhs_options
    end
  end

  class HasAndBelongsToMany < CollectionAssociation #:nodoc:
    def macro
      :has_and_belongs_to_many
    end

    def valid_options
      super + [:join_table, :association_foreign_key]
    end

    def self.define_callbacks(model, reflection)
      super
      name = reflection.name
      model.send(:include, Module.new {
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def destroy_associations
            association(:#{name}).delete_all
            super
          end
        RUBY
      })
    end
  end
end
