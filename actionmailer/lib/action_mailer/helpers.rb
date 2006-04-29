module ActionMailer
  module Helpers #:nodoc:
    def self.included(base) #:nodoc:
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

        # Wrap initialize_template_class to extend new template class
        # instances with the master helper module.
        alias_method_chain :initialize_template_class, :helper
      end
    end

    module ClassMethods
      # Makes all the (instance) methods in the helper module available to templates rendered through this controller.
      # See ActionView::Helpers (link:classes/ActionView/Helpers.html) for more about making your own helper modules 
      # available to the templates.
      def add_template_helper(helper_module) #:nodoc:
        master_helper_module.module_eval "include #{helper_module}"
      end

      # Declare a helper:
      #   helper :foo
      # requires 'foo_helper' and includes FooHelper in the template class.
      #   helper FooHelper
      # includes FooHelper in the template class.
      #   helper { def foo() "#{bar} is the very best" end }
      # evaluates the block in the template class, adding method #foo.
      #   helper(:three, BlindHelper) { def mice() 'mice' end }
      # does all three.
      def helper(*args, &block)
        args.flatten.each do |arg|
          case arg
            when Module
              add_template_helper(arg)
            when String, Symbol
              file_name  = arg.to_s.underscore + '_helper'
              class_name = file_name.camelize
                
              begin
                require_dependency(file_name)
              rescue LoadError => load_error
                requiree = / -- (.*?)(\.rb)?$/.match(load_error).to_a[1]
                msg = (requiree == file_name) ? "Missing helper file helpers/#{file_name}.rb" : "Can't load file: #{requiree}"
                raise LoadError.new(msg).copy_blame!(load_error)
              end

              add_template_helper(class_name.constantize)
            else
              raise ArgumentError, 'helper expects String, Symbol, or Module argument'
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
        def inherited_with_helper(child)
          inherited_without_helper(child)
          begin
            child.master_helper_module = Module.new
            child.master_helper_module.send :include, master_helper_module
            child.helper child.name.underscore
          rescue MissingSourceFile => e
            raise unless e.is_missing?("helpers/#{child.name.underscore}_helper")
          end
        end        
    end

    private
      # Extend the template class instance with our controller's helper module.
      def initialize_template_class_with_helper(assigns)
        returning(template = initialize_template_class_without_helper(assigns)) do
          template.extend self.class.master_helper_module
        end
      end
  end
end