module ActionController #:nodoc:
  module Helpers #:nodoc:
    HELPERS_DIR = (defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/app/helpers" : "app/helpers")

    def self.included(base)
      # Initialize the base module to aggregate its helpers.
      base.class_inheritable_accessor :master_helper_module
      base.master_helper_module = Module.new

      # Extend base with class methods to declare helpers.
      base.extend(ClassMethods)

      base.class_eval do
        # Wrap inherited to create a new master helper module for subclasses.
        class << self
          alias_method_chain :inherited, :helper
        end
      end
    end

    # The template helpers serve to relieve the templates from including the same inline code again and again. It's a
    # set of standardized methods for working with forms (FormHelper), dates (DateHelper), texts (TextHelper), and
    # Active Records (ActiveRecordHelper) that's available to all templates by default.
    #
    # It's also really easy to make your own helpers and it's much encouraged to keep the template files free
    # from complicated logic. It's even encouraged to bundle common compositions of methods from other helpers
    # (often the common helpers) as they're used by the specific application.
    #
    #   module MyHelper
    #     def hello_world() "hello world" end
    #   end
    #
    # MyHelper can now be included in a controller, like this:
    #
    #   class MyController < ActionController::Base
    #     helper :my_helper
    #   end
    #
    # ...and, same as above, used in any template rendered from MyController, like this:
    #
    # Let's hear what the helper has to say: <tt><%= hello_world %></tt>
    module ClassMethods
      # Makes all the (instance) methods in the helper module available to templates rendered through this controller.
      # See ActionView::Helpers (link:classes/ActionView/Helpers.html) for more about making your own helper modules
      # available to the templates.
      def add_template_helper(helper_module) #:nodoc:
        master_helper_module.send(:include, helper_module)
      end

      # Declare a helper:
      #
      #   helper :foo
      # requires 'foo_helper' and includes FooHelper in the template class.
      #
      #   helper FooHelper
      # includes FooHelper in the template class.
      #
      #   helper { def foo() "#{bar} is the very best" end }
      # evaluates the block in the template class, adding method #foo.
      #
      #   helper(:three, BlindHelper) { def mice() 'mice' end }
      # does all three.
      #
      #   helper :all
      # includes all helpers from app/views/helpers/**/*.rb under RAILS_ROOT
      def helper(*args, &block)
        args.flatten.each do |arg|
          case arg
            when Module
              add_template_helper(arg)
            when :all
              helper(all_application_helpers)
            when String, Symbol
              file_name  = arg.to_s.underscore + '_helper'
              class_name = file_name.camelize

              begin
                require_dependency(file_name)
              rescue LoadError => load_error
                requiree = / -- (.*?)(\.rb)?$/.match(load_error).to_a[1]
                if requiree == file_name
                  msg = "Missing helper file helpers/#{file_name}.rb"
                  raise LoadError.new(msg).copy_blame!(load_error)
                else
                  raise
                end
              end

              add_template_helper(class_name.constantize)
            else
              raise ArgumentError, "helper expects String, Symbol, or Module argument (was: #{args.inspect})"
          end
        end

        # Evaluate block in template class if given.
        master_helper_module.module_eval(&block) if block_given?
      end

      # Declare a controller method as a helper.  For example,
      #   helper_method :link_to
      #   def link_to(name, options) ... end
      # makes the link_to controller method available in the view.
      def helper_method(*methods)
        methods.flatten.each do |method|
          master_helper_module.module_eval <<-end_eval
            def #{method}(*args, &block)
              controller.send(%(#{method}), *args, &block)
            end
          end_eval
        end
      end

      # Declare a controller attribute as a helper.  For example,
      #   helper_attr :name
      #   attr_accessor :name
      # makes the name and name= controller methods available in the view.
      # The is a convenience wrapper for helper_method.
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end


      private
        def default_helper_module!
          module_name = name.sub(/Controller$|$/, 'Helper')
          module_path = module_name.split('::').map { |m| m.underscore }.join('/')
          require_dependency module_path
          helper module_name.constantize
        rescue LoadError => e
          raise unless e.is_missing? module_path
          logger.debug("#{name}: missing default helper path #{module_path}") if logger
        rescue NameError => e
          raise unless e.missing_name? module_name
          logger.debug("#{name}: missing default helper module #{module_name}") if logger
        end

        def inherited_with_helper(child)
          inherited_without_helper(child)

          begin
            child.master_helper_module = Module.new
            child.master_helper_module.send :include, master_helper_module
            child.send :default_helper_module!
          rescue MissingSourceFile => e
            raise unless e.is_missing?("helpers/#{child.controller_path}_helper")
          end
        end

        # Extract helper names from files in app/helpers/**/*.rb
        def all_application_helpers
          extract = /^#{Regexp.quote(HELPERS_DIR)}\/?(.*)_helper.rb$/
          Dir["#{HELPERS_DIR}/**/*_helper.rb"].map { |file| file.sub extract, '\1' }
        end
    end
  end
end
