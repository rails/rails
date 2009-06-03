module AbstractController
  module Callbacks
    extend ActiveSupport::Concern

    include ActiveSupport::NewCallbacks

    included do
      define_callbacks :process_action, "response_body"
    end

    def process_action(method_name)
      _run_process_action_callbacks(method_name) do
        super
      end
    end

    module ClassMethods
      def _normalize_callback_options(options)
        if only = options[:only]
          only = Array(only).map {|o| "action_name == '#{o}'"}.join(" || ")
          options[:per_key] = {:if => only}
        end
        if except = options[:except]
          except = Array(except).map {|e| "action_name == '#{e}'"}.join(" || ")
          options[:per_key] = {:unless => except}
        end
      end

      def skip_filter(*names, &blk)
        skip_before_filter(*names, &blk)
        skip_after_filter(*names, &blk)
        skip_around_filter(*names, &blk)
      end

      def _insert_callbacks(names, block)
        options = names.last.is_a?(Hash) ? names.pop : {}
        _normalize_callback_options(options)
        names.push(block) if block
        names.each do |name|
          yield name, options
        end
      end

      [:before, :after, :around].each do |filter|
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def #{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              _set_callback(:process_action, :#{filter}, name, options)
            end
          end

          def prepend_#{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              _set_callback(:process_action, :#{filter}, name, options.merge(:prepend => true))
            end
          end

          def skip_#{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              _skip_callback(:process_action, :#{filter}, name, options)
            end
          end

          alias_method :append_#{filter}_filter, :#{filter}_filter
        RUBY_EVAL
      end
    end
  end
end
