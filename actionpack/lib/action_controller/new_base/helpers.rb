require 'active_support/core_ext/load_error'
require 'active_support/core_ext/name_error'
require 'active_support/dependencies'

module ActionController
  module Helpers
    extend ActiveSupport::Concern

    include AbstractController::Helpers

    included do
      # Set the default directory for helpers
      class_inheritable_accessor :helpers_dir
      self.helpers_dir = (defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/app/helpers" : "app/helpers")
    end

    module ClassMethods
      def inherited(klass)
        klass.__send__ :default_helper_module!
        super
      end

      # The +helper+ class method can take a series of helper module names, a block, or both.
      #
      # * <tt>*args</tt>: One or more modules, strings or symbols, or the special symbol <tt>:all</tt>.
      # * <tt>&block</tt>: A block defining helper methods.
      #
      # ==== Examples
      # When the argument is a string or symbol, the method will provide the "_helper" suffix, require the file
      # and include the module in the template class.  The second form illustrates how to include custom helpers
      # when working with namespaced controllers, or other cases where the file containing the helper definition is not
      # in one of Rails' standard load paths:
      #   helper :foo             # => requires 'foo_helper' and includes FooHelper
      #   helper 'resources/foo'  # => requires 'resources/foo_helper' and includes Resources::FooHelper
      #
      # When the argument is a module it will be included directly in the template class.
      #   helper FooHelper # => includes FooHelper
      #
      # When the argument is the symbol <tt>:all</tt>, the controller will include all helpers beneath
      # <tt>ActionController::Base.helpers_dir</tt> (defaults to <tt>app/helpers/**/*.rb</tt> under RAILS_ROOT).
      #   helper :all
      #
      # Additionally, the +helper+ class method can receive and evaluate a block, making the methods defined available
      # to the template.
      #   # One line
      #   helper { def hello() "Hello, world!" end }
      #   # Multi-line
      #   helper do
      #     def foo(bar)
      #       "#{bar} is the very best"
      #     end
      #   end
      #
      # Finally, all the above styles can be mixed together, and the +helper+ method can be invoked with a mix of
      # +symbols+, +strings+, +modules+ and blocks.
      #   helper(:three, BlindHelper) { def mice() 'mice' end }
      #
      def helper(*args, &block)
        args.flatten.each do |arg|
          case arg
          when :all
            helper all_application_helpers
          when String, Symbol
            file_name  = arg.to_s.underscore + '_helper'
            class_name = file_name.camelize

            begin
              require_dependency(file_name)
            rescue LoadError => load_error
              requiree = / -- (.*?)(\.rb)?$/.match(load_error.message).to_a[1]
              if requiree == file_name
                msg = "Missing helper file helpers/#{file_name}.rb"
                raise LoadError.new(msg).copy_blame!(load_error)
              else
                raise
              end
            end

            super class_name.constantize
          else
            super args
          end
        end

        # Evaluate block in template class if given.
        master_helper_module.module_eval(&block) if block_given?
      end

      # Declares helper accessors for controller attributes. For example, the
      # following adds new +name+ and <tt>name=</tt> instance methods to a
      # controller and makes them available to the view:
      #   helper_attr :name
      #   attr_accessor :name
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end

      # Provides a proxy to access helpers methods from outside the view.
      def helpers
        unless @helper_proxy
          @helper_proxy = ActionView::Base.new
          @helper_proxy.extend master_helper_module
        else
          @helper_proxy
        end
      end

      private
        def default_helper_module!
          unless name.blank?
            module_name = name.sub(/Controller$|$/, 'Helper')
            module_path = module_name.split('::').map { |m| m.underscore }.join('/')
            require_dependency module_path
            helper module_name.constantize
          end
        rescue MissingSourceFile => e
          raise unless e.is_missing? module_path
        rescue NameError => e
          raise unless e.missing_name? module_name
        end

        # Extract helper names from files in app/helpers/**/*.rb
        def all_application_helpers
          extract = /^#{Regexp.quote(helpers_dir)}\/?(.*)_helper.rb$/
          Dir["#{helpers_dir}/**/*_helper.rb"].map { |file| file.sub extract, '\1' }
        end
    end
  end
end
