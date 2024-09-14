# frozen_string_literal: true

module ActiveRecord::Associations::Builder # :nodoc:
  class HasAndBelongsToMany # :nodoc:
    attr_reader :lhs_model, :association_name, :options

    def initialize(association_name, lhs_model, options)
      @association_name = association_name
      @lhs_model = lhs_model
      @options = options
    end

    def through_model
      join_model = Class.new(ActiveRecord::Base) {
        class << self
          attr_accessor :left_model
          attr_accessor :name
          attr_accessor :table_name_resolver
          attr_accessor :left_reflection
          attr_accessor :right_reflection
        end

        @table_name = nil
        def self.table_name
          # Table name needs to be resolved lazily
          # because RHS class might not have been loaded
          @table_name ||= table_name_resolver.call
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

        def self.connection_pool
          left_model.connection_pool
        end
      }

      join_model.name                = "HABTM_#{association_name.to_s.camelize}"
      join_model.table_name_resolver = -> { table_name }
      join_model.left_model          = lhs_model

      join_model.add_left_association :left_side, anonymous_class: lhs_model
      join_model.add_right_association association_name, belongs_to_options(options)
      join_model
    end

    def middle_reflection(join_model)
      middle_name = [lhs_model.name.downcase.pluralize,
                     association_name.to_s].sort.join("_").gsub("::", "_").to_sym
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
        if options.key? :foreign_key
          middle_options[:foreign_key] = options[:foreign_key]
        end
        middle_options
      end

      def table_name
        if options[:join_table]
          options[:join_table].to_s
        else
          class_name = options.fetch(:class_name) {
            association_name.to_s.camelize.singularize
          }
          klass = lhs_model.send(:compute_type, class_name.to_s)
          [lhs_model.table_name, klass.table_name].sort.join("\0").gsub(/^(.*[._])(.+)\0\1(.+)/, '\1\2_\3').tr("\0", "_")
        end
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
