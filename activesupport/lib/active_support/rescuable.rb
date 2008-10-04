module ActiveSupport
  module Rescuable
    def self.included(base) # :nodoc:
      base.class_inheritable_array :rescue_handlers
      base.rescue_handlers = []
      base.extend(ClassMethods)
    end

    module ClassMethods
      def enable_rescue_for(*methods)
        methods.each do |method|
          class_eval <<-EOS
            def #{method}_with_rescue(*args, &block)
              #{method}_without_rescue(*args, &block)
            rescue Exception => exception
              rescue_with_handler(exception)
            end

            alias_method_chain :#{method}, :rescue
          EOS
        end
      end

      def rescue_from(*klasses, &block)
        options = klasses.extract_options!
        unless options.has_key?(:with)
          if block_given?
            options[:with] = block
          else
            raise ArgumentError, "Need a handler. Supply an options hash that has a :with key as the last argument."
          end
        end

        klasses.each do |klass|
          key = if klass.is_a?(Class) && klass <= Exception
            klass.name
          elsif klass.is_a?(String)
            klass
          else
            raise ArgumentError, "#{klass} is neither an Exception nor a String"
          end

          # put the new handler at the end because the list is read in reverse
          rescue_handlers << [key, options[:with]]
        end
      end
    end

    def rescue_with_handler(exception)
      if handler = handler_for_rescue(exception)
        handler.arity != 0 ? handler.call(exception) : handler.call
      else
        raise exception
      end
    end

    def handler_for_rescue(exception)
      # use reverse so what is added last is found first
      _, handler = *rescue_handlers.reverse.detect do |klass_name, handler|
        # allow strings to support constants that are not defined yet
        klass = self.class.const_get(klass_name) rescue nil
        klass ||= klass_name.constantize rescue nil
        exception.is_a?(klass) if klass
      end

      case handler
      when Symbol
        method(handler)
      when Proc
        handler.bind(self)
      end
    end
  end
end
