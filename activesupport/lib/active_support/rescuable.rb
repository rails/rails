require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/proc'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  # Rescuable module adds support for easier exception handling.
  module Rescuable
    extend Concern

    included do
      class_attribute :rescue_handlers
      self.rescue_handlers = []
    end

    module ClassMethods
      # Rescue exceptions raised in controller actions.
      #
      # <tt>rescue_from</tt> receives a series of exception classes or class
      # names, and a trailing <tt>:with</tt> option with the name of a method
      # or a Proc object to be called to handle them. Alternatively a block can
      # be given.
      #
      # Handlers that take one argument will be called with the exception, so
      # that the exception can be inspected when dealing with it.
      #
      # Handlers are inherited. They are searched from right to left, from
      # bottom to top, and up the hierarchy. The handler of the first class for
      # which <tt>exception.is_a?(klass)</tt> holds true is the one invoked, if
      # any.
      #
      #   class ApplicationController < ActionController::Base
      #     rescue_from User::NotAuthorized, with: :deny_access # self defined exception
      #     rescue_from ActiveRecord::RecordInvalid, with: :show_errors
      #
      #     rescue_from 'MyAppError::Base' do |exception|
      #       render xml: exception, status: 500
      #     end
      #
      #     protected
      #       def deny_access
      #         ...
      #       end
      #
      #       def show_errors(exception)
      #         exception.record.new_record? ? ...
      #       end
      #   end
      #
      # Exceptions raised inside exception handlers are not propagated up.
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
          self.rescue_handlers += [[key, options[:with]]]
        end
      end
    end

    # Tries to rescue the exception by looking up and calling a registered handler.
    def rescue_with_handler(exception)
      if handler = handler_for_rescue(exception)
        handler.arity != 0 ? handler.call(exception) : handler.call
        true # don't rely on the return value of the handler
      end
    end

    def handler_for_rescue(exception)
      # We go from right to left because pairs are pushed onto rescue_handlers
      # as rescue_from declarations are found.
      _, rescuer = self.class.rescue_handlers.reverse.detect do |klass_name, handler|
        # The purpose of allowing strings in rescue_from is to support the
        # declaration of handler associations for exception classes whose
        # definition is yet unknown.
        #
        # Since this loop needs the constants it would be inconsistent to
        # assume they should exist at this point. An early raised exception
        # could trigger some other handler and the array could include
        # precisely a string whose corresponding constant has not yet been
        # seen. This is why we are tolerant to unknown constants.
        #
        # Note that this tolerance only matters if the exception was given as
        # a string, otherwise a NameError will be raised by the interpreter
        # itself when rescue_from CONSTANT is executed.
        klass = self.class.const_get(klass_name) rescue nil
        klass ||= klass_name.constantize rescue nil
        exception.is_a?(klass) if klass
      end

      case rescuer
      when Symbol
        method(rescuer)
      when Proc
        if rescuer.arity == 0
          Proc.new { instance_exec(&rescuer) }
        else
          Proc.new { |_exception| instance_exec(_exception, &rescuer) }
        end
      end
    end
  end
end
