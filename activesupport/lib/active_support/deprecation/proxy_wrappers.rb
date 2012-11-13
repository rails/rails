require 'active_support/inflector/methods'

module ActiveSupport
  class Deprecation
    class DeprecationProxy #:nodoc:
      def self.new(*args, &block)
        object = args.first

        return object unless object
        super
      end

      instance_methods.each { |m| undef_method m unless m =~ /^__|^object_id$/ }

      # Don't give a deprecation warning on inspect since test/unit and error
      # logs rely on it for diagnostics.
      def inspect
        target.inspect
      end

      private
        def method_missing(called, *args, &block)
          warn caller, called, args
          target.__send__(called, *args, &block)
        end
    end

    # This DeprecatedObjectProxy transforms object to depracated object.
    #
    #   @old_object = DeprecatedObjectProxy.new(Object.new, "Don't use this object anymore!")
    #   @old_object = DeprecatedObjectProxy.new(Object.new, "Don't use this object anymore!", deprecator_instance)
    #
    # When someone execute any method expect +inspect+ on proxy object this will
    # trigger +warn+ method on +deprecator_instance+.
    #
    # Default deprecator is <tt>ActiveSupport::Deprecation</tt>
    class DeprecatedObjectProxy < DeprecationProxy
      def initialize(object, message, deprecator = ActiveSupport::Deprecation.instance)
        @object = object
        @message = message
        @deprecator = deprecator
      end

      private
        def target
          @object
        end

        def warn(callstack, called, args)
          @deprecator.warn(@message, callstack)
        end
    end

    # This DeprecatedInstanceVariableProxy transforms instance variable to
    # depracated instance variable.
    #
    #   class Example
    #     def initialize(deprecator)
    #       @request = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :request, :@request, deprecator)
    #       @_request = :a_request
    #     end
    #
    #     def request
    #       @_request
    #     end
    #
    #     def old_request
    #       @request
    #     end
    #   end
    #
    # When someone execute any method on @request variable this will trigger
    # +warn+ method on +deprecator_instance+ and will fetch <tt>@_request</tt>
    # variable via +request+ method and execute the same method on non-proxy
    # instance variable.
    #
    # Default deprecator is <tt>ActiveSupport::Deprecation</tt>.
    class DeprecatedInstanceVariableProxy < DeprecationProxy
      def initialize(instance, method, var = "@#{method}", deprecator = ActiveSupport::Deprecation.instance)
        @instance = instance
        @method = method
        @var = var
        @deprecator = deprecator
      end

      private
        def target
          @instance.__send__(@method)
        end

        def warn(callstack, called, args)
          @deprecator.warn("#{@var} is deprecated! Call #{@method}.#{called} instead of #{@var}.#{called}. Args: #{args.inspect}", callstack)
        end
    end

    # This DeprecatedConstantProxy transforms constant to depracated constant.
    #
    #   OLD_CONST = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('OLD_CONST', 'NEW_CONST')
    #   OLD_CONST = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('OLD_CONST', 'NEW_CONST', deprecator_instance)
    #
    # When someone use old constant this will trigger +warn+ method on
    # +deprecator_instance+.
    #
    # Default deprecator is <tt>ActiveSupport::Deprecation</tt>.
    class DeprecatedConstantProxy < DeprecationProxy
      def initialize(old_const, new_const, deprecator = ActiveSupport::Deprecation.instance)
        @old_const = old_const
        @new_const = new_const
        @deprecator = deprecator
      end

      def class
        target.class
      end

      private
        def target
          ActiveSupport::Inflector.constantize(@new_const.to_s)
        end

        def warn(callstack, called, args)
          @deprecator.warn("#{@old_const} is deprecated! Use #{@new_const} instead.", callstack)
        end
    end
  end
end
