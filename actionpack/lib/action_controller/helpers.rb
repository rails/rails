module ActionController #:nodoc:
  module Helpers #:nodoc:
    def self.append_features(base)
      super
      base.class_eval { class << self; alias_method :inherited_without_helper, :inherited; end }
      base.extend(ClassMethods)
    end

    # The template helpers serves to relieve the templates from including the same inline code again and again. It's a
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
        template_class.class_eval "include #{helper_module}"
      end

      # Declare a helper.  If you use this method in your controller, you don't
      # have to do the +self.append_features+ incantation in your helper class.
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
            file_name  = Inflector.underscore(arg.to_s.downcase) + '_helper'
            class_name = Inflector.camelize(file_name)
            begin
              require_dependency(file_name)
            rescue LoadError => load_error
              requiree = / -- (.*?)(\.rb)?$/.match(load_error).to_a[1]
              if requiree == file_name
                raise LoadError, "Missing helper file helpers/#{file_name}.rb"
              else
                raise LoadError, "Can't load file: #{requiree}"
              end
            end
            raise ArgumentError, "Missing #{class_name} module in helpers/#{file_name}.rb" unless Object.const_defined?(class_name)
            add_template_helper(Object.const_get(class_name))
          else
            raise ArgumentError, 'helper expects String, Symbol, or Module argument'
          end
        end

        # Evaluate block in template class if given.
        template_class.module_eval(&block) if block_given?
      end

      # Declare a controller method as a helper.  For example,
      #   helper_method :link_to
      #   def link_to(name, options) ... end
      # makes the link_to controller method available in the view.
      def helper_method(*methods)
        template_class.controller_delegate(*methods)
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
        def inherited(child)
          inherited_without_helper(child)
          begin
            child.helper(child.controller_name)
          rescue ArgumentError, LoadError
            # No default helper available for this controller
          end
        end        
    end
  end
end
