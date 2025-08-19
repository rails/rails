# frozen_string_literal: true

module ActiveRecord
  # = Active Record Selected Columns
  #
  # Provides a mechanism to temporarily limit the visible columns for ActiveRecord models
  # within a specific block context. This is useful for scenarios where you want to
  # explicitly control which columns are accessible during queries, helping with
  # performance optimization and data access control.
  #
  #   # Show only specific columns for a model within a block
  #   ActiveRecord::SelectedColumns.with_selected_columns_for(
  #     User: [:id, :name],
  #     Post: [:id, :title]
  #   ) do
  #     User.first.inspect  # Only shows id and name
  #     Post.all.to_a       # Only includes id and title columns
  #   end
  #
  # The method supports nested calls, where inner contexts can further restrict columns:
  #
  #   ActiveRecord::SelectedColumns.with_selected_columns_for(User: [:id, :name, :email]) do
  #     puts User.first.inspect  # Shows id, name, email
  #
  #     ActiveRecord::SelectedColumns.with_selected_columns_for(User: [:id, :name]) do
  #       puts User.first.inspect  # Shows only id, name
  #     end
  #
  #     puts User.first.inspect  # Shows id, name, email again
  #   end
  #
  # The implementation is fully thread-safe, using thread-local storage to maintain
  # independent contexts per thread. Each thread maintains its own context stack,
  # allowing for proper nested calls and automatic restoration even when exceptions occur.
  module SelectedColumns
    THREAD_CTX_KEY = :ar_selected_columns_ctx

    module ThreadSafeInterceptors # :nodoc:
      def attribute_names
        ctx = Thread.current[THREAD_CTX_KEY]
        model_class = self.is_a?(Class) ? self : self.class
        if ctx && (selected_columns = ctx.models[model_class])
          return selected_columns
        end
        super
      end

      def columns_hash
        ctx = Thread.current[THREAD_CTX_KEY]
        model_class = self.is_a?(Class) ? self : self.class
        if ctx && (selected_columns = ctx.models[model_class])
          return super.select { |name, _| selected_columns.include?(name) }
        end
        super
      end

      def respond_to?(method_name, include_private = false)
        ctx = Thread.current[THREAD_CTX_KEY]
        model_class = self.is_a?(Class) ? self : self.class
        if ctx && (selected_columns = ctx.models[model_class])
          attr_name = method_name.to_s.gsub(/[=?!]$/, "")

          if _attribute_method?(attr_name, model_class) && !selected_columns.include?(attr_name)
            return false
          end
        end
        super
      end

      private
        def _attribute_method?(attr_name, model_class)
          original_ctx = Thread.current[THREAD_CTX_KEY]
          Thread.current[THREAD_CTX_KEY] = nil
          begin
            model_class.attribute_names.include?(attr_name)
          ensure
            Thread.current[THREAD_CTX_KEY] = original_ctx
          end
        end
    end

    class Context # :nodoc:
      attr_reader :models, :previous_context

      def initialize(models_columns)
        @models = models_columns
        @previous_context = Thread.current[THREAD_CTX_KEY]
      end

      def apply!
        Thread.current[THREAD_CTX_KEY] = self

        @models.each_key do |model_class|
          unless model_class.included_modules.include?(ThreadSafeInterceptors)
            model_class.prepend(ThreadSafeInterceptors)
            model_class.singleton_class.prepend(ThreadSafeInterceptors)
          end
        end
      end

      def restore!
        Thread.current[THREAD_CTX_KEY] = @previous_context
      end
    end

    def self.resolve_model(model_ref) # :nodoc:
      case model_ref
      when Class
        unless model_ref < ActiveRecord::Base
          raise ArgumentError, "#{model_ref} is not an ActiveRecord model"
        end
        model_ref
      when String, Symbol
        model_class = model_ref.to_s.classify.constantize
        unless model_class < ActiveRecord::Base
          raise ArgumentError, "#{model_ref} does not resolve to an ActiveRecord model"
        end
        model_class
      else
        raise ArgumentError, "#{model_ref} is not a valid ActiveRecord model"
      end
    rescue NameError
      raise ArgumentError, "Could not resolve model: #{model_ref}"
    end

  module_function

  # Temporarily select specific columns for given models within a block.
  #
  # ==== Parameters
  #
  # * +models_cols+ - Hash mapping models to their selected columns, or separate model and columns arguments
  #
  # ==== Examples
  #
  #   ActiveRecord::SelectedColumns.with_selected_columns_for(User => [:name, :email]) do
  #     users = User.all
  #     users.each { |user| puts user.name }
  #   end
  #
  #   ActiveRecord::SelectedColumns.with_selected_columns_for(User, [:name, :email]) do
  #     User.first.inspect # Only shows name and email
  #   end
  def with_selected_columns_for(*args)
    models_cols = if args.length == 1 && args.first.is_a?(Hash)
      args.first
    elsif args.length == 2
      { args.first => args.second }
    else
      raise ArgumentError, "Expected (model_hash) or (model, columns), got #{args.length} arguments"
    end

    return yield if models_cols.empty?

    unless block_given?
      raise ArgumentError, "block required"
    end

    normalized_pairs = models_cols.map { |model_ref, cols| [SelectedColumns.resolve_model(model_ref), Array(cols).map(&:to_s)] }

    enhanced_models_columns = {}

    normalized_pairs.each do |model_class, selected_columns|
      enhanced_columns = selected_columns.dup

      table_name = model_class.table_name
      available_columns = model_class.with_connection { |conn| conn.columns(table_name).map(&:name) }

      if model_class.respond_to?(:defined_enums)
        enum_columns = model_class.defined_enums.keys
        enhanced_columns += enum_columns.reject { |col| enhanced_columns.include?(col) }
      end

      if model_class.respond_to?(:attribute_aliases) && model_class.attribute_aliases.present?
        model_class.attribute_aliases.each do |alias_name, actual_column|
          if available_columns.include?(actual_column.to_s) && !enhanced_columns.include?(actual_column.to_s)
            enhanced_columns << actual_column.to_s
          end
        end
      end

      invalid_columns = enhanced_columns - available_columns
      unless invalid_columns.empty?
        raise ArgumentError, "unknown columns for #{model_class}: #{invalid_columns.join(', ')}"
      end

      enhanced_models_columns[model_class] = enhanced_columns
    end

    context = Context.new(enhanced_models_columns)
    context.apply!

    begin
      yield
    ensure
      context.restore!
    end
  end
  end
end
