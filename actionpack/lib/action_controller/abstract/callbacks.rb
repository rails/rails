module AbstractController
  module Callbacks
    extend ActiveSupport::DependencyModule

    depends_on ActiveSupport::NewCallbacks

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
      
      [:before, :after, :around].each do |filter|
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def #{filter}_filter(*names, &blk)
            options = names.last.is_a?(Hash) ? names.pop : {}
            _normalize_callback_options(options)
            names.push(blk) if block_given?
            names.each do |name|
              process_action_callback(:#{filter}, name, options)
            end
          end

          def skip_#{filter}_filter(*names, &blk)
            options = names.last.is_a?(Hash) ? names.pop : {}
            _normalize_callback_options(options)
            names.push(blk) if block_given?
            names.each do |name|
              skip_process_action_callback(:#{filter}, name, options)
            end
          end

          alias_method :append_#{filter}_filter, :#{filter}_filter
        RUBY_EVAL
      end
    end
  end
end