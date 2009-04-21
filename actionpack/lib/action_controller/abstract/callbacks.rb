module AbstractController
  module Callbacks
    setup do
      include ActiveSupport::NewCallbacks
      define_callbacks :process_action      
    end
    
    def process_action
      _run_process_action_callbacks(action_name) do
        super
      end
    end
    
    module ClassMethods
      def _normalize_callback_options(options)
        if only = options[:only]
          only = Array(only).map {|o| "action_name == :#{o}"}.join(" || ")
          options[:per_key] = {:if => only}
        end
        if except = options[:except]
          except = Array(except).map {|e| "action_name == :#{e}"}.join(" || ")          
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
        RUBY_EVAL
      end
    end
  end
end