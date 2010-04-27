require 'active_support/dependencies'

module AbstractController
  module Helpers
    extend ActiveSupport::Concern

    include Rendering

    included do
      class_attribute :_helpers
      self._helpers = Module.new
    end

    module ClassMethods
      # When a class is inherited, wrap its helper module in a new module.
      # This ensures that the parent class's module can be changed
      # independently of the child class's.
      def inherited(klass)
        helpers = _helpers
        klass._helpers = Module.new { include helpers }
        klass.class_eval { default_helper_module! unless anonymous? }
        super
      end

      # Declare a controller method as a helper. For example, the following
      # makes the +current_user+ controller method available to the view:
      #   class ApplicationController < ActionController::Base
      #     helper_method :current_user, :logged_in?
      #
      #     def current_user
      #       @current_user ||= User.find_by_id(session[:user])
      #     end
      #
      #      def logged_in?
      #        current_user != nil
      #      end
      #   end
      #
      # In a view:
      #  <% if logged_in? -%>Welcome, <%= current_user.name %><% end -%>
      #
      # ==== Parameters
      # meths<Array[#to_s]>:: The name of a method on the controller
      #   to be made available on the view.
      def helper_method(*meths)
        meths.flatten.each do |meth|
          _helpers.class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def #{meth}(*args, &blk)
              controller.send(%(#{meth}), *args, &blk)
            end
          ruby_eval
        end
      end

      # The +helper+ class method can take a series of helper module names, a block, or both.
      #
      # ==== Parameters
      # *args<Array[Module, Symbol, String, :all]>
      # block<Block>:: A block defining helper methods
      #
      # ==== Examples
      # When the argument is a module it will be included directly in the template class.
      #   helper FooHelper # => includes FooHelper
      #
      # When the argument is a string or symbol, the method will provide the "_helper" suffix, require the file
      # and include the module in the template class.  The second form illustrates how to include custom helpers
      # when working with namespaced controllers, or other cases where the file containing the helper definition is not
      # in one of Rails' standard load paths:
      #   helper :foo             # => requires 'foo_helper' and includes FooHelper
      #   helper 'resources/foo'  # => requires 'resources/foo_helper' and includes Resources::FooHelper
      #
      # Additionally, the +helper+ class method can receive and evaluate a block, making the methods defined available
      # to the template.
      #
      #   # One line
      #   helper { def hello() "Hello, world!" end }
      #
      #   # Multi-line
      #   helper do
      #     def foo(bar)
      #       "#{bar} is the very best"
      #     end
      #   end
      #
      # Finally, all the above styles can be mixed together, and the +helper+ method can be invoked with a mix of
      # +symbols+, +strings+, +modules+ and blocks.
      #
      #   helper(:three, BlindHelper) { def mice() 'mice' end }
      #
      def helper(*args, &block)
        modules_for_helpers(args).each do |mod|
          add_template_helper(mod)
        end

        _helpers.module_eval(&block) if block_given?
      end

      private
      # Makes all the (instance) methods in the helper module available to templates
      # rendered through this controller.
      #
      # ==== Parameters
      # mod<Module>:: The module to include into the current helper module
      #   for the class
      def add_template_helper(mod)
        _helpers.module_eval { include mod }
      end

      # Returns a list of modules, normalized from the acceptable kinds of
      # helpers with the following behavior:
      #
      # String or Symbol:: :FooBar or "FooBar" becomes "foo_bar_helper",
      #   and "foo_bar_helper.rb" is loaded using require_dependency.
      #
      # Module:: No further processing
      #
      # After loading the appropriate files, the corresponding modules
      # are returned.
      #
      # ==== Parameters
      # args<Array[String, Symbol, Module]>:: A list of helpers
      #
      # ==== Returns
      # Array[Module]:: A normalized list of modules for the list of
      #   helpers provided.
      def modules_for_helpers(args)
        args.flatten.map! do |arg|
          case arg
          when String, Symbol
            file_name = "#{arg.to_s.underscore}_helper"
            require_dependency(file_name, "Missing helper file helpers/%s.rb")
            file_name.camelize.constantize
          when Module
            arg
          else
            raise ArgumentError, "helper must be a String, Symbol, or Module"
          end
        end
      end

      def default_helper_module!
        module_name = name.sub(/Controller$/, '')
        module_path = module_name.underscore
        helper module_path
      rescue MissingSourceFile => e
        raise e unless e.is_missing? "helpers/#{module_path}_helper"
      rescue NameError => e
        raise e unless e.missing_name? "#{module_name}Helper"
      end
    end
  end
end
