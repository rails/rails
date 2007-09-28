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

    # The Rails framework provides a large number of helpers for working with +assets+, +dates+, +forms+, 
    # +numbers+ and +ActiveRecord+ objects, to name a few. These helpers are available to all templates
    # by default.
    #
    # In addition to using the standard template helpers provided in the Rails framework, creating custom helpers to
    # extract complicated logic or reusable functionality is strongly encouraged.  By default, the controller will 
    # include a helper whose name matches that of the controller, e.g., <tt>MyController</tt> will automatically
    # include <tt>MyHelper</tt>.
    # 
    # Additional helpers can be specified using the +helper+ class method in <tt>ActionController::Base</tt> or any
    # controller which inherits from it.
    #
    # ==== Examples
    # The +to_s+ method from the +Time+ class can be wrapped in a helper method to display a custom message if 
    # the Time object is blank:
    #
    #   module FormattedTimeHelper
    #     def format_time(time, format=:long, blank_message="&nbsp;")
    #       time.blank? ? blank_message : time.to_s(format)
    #     end
    #   end
    #
    # +FormattedTimeHelper+ can now be included in a controller, using the +helper+ class method:
    #
    #   class EventsController < ActionController::Base
    #     helper FormattedTimeHelper
    #     def index
    #       @events = Event.find(:all)
    #     end
    #   end
    #
    # Then, in any view rendered by <tt>EventController</tt>, the <tt>format_time</tt> method can be called:
    #
    #   <% @events.each do |event| -%>
    #     <p>
    #       <% format_time(event.time, :short, "N/A") %> | <%= event.name %> 
    #     </p>
    #   <% end -%>
    #
    # Finally, assuming we have two event instances, one which has a time and one which does not, 
    # the output might look like this:
    #
    #   23 Aug 11:30 | Carolina Railhawks Soccer Match 
    #   N/A | Carolina Railhaws Training Workshop
    #
    module ClassMethods
      # Makes all the (instance) methods in the helper module available to templates rendered through this controller.
      # See ActionView::Helpers (link:classes/ActionView/Helpers.html) for more about making your own helper modules
      # available to the templates.
      def add_template_helper(helper_module) #:nodoc:
        master_helper_module.send(:include, helper_module)
      end

      # The +helper+ class method can take a series of helper module names, a block, or both.
      #
      # * <tt>*args</tt>: One or more +Modules+, +Strings+ or +Symbols+, or the special symbol <tt>:all</tt>.
      # * <tt>&block</tt>: A block defining helper methods.
      # 
      # ==== Examples
      # When the argument is a +String+ or +Symbol+, the method will provide the "_helper" suffix, require the file 
      # and include the module in the template class.  The second form illustrates how to include custom helpers 
      # when working with namespaced controllers, or other cases where the file containing the helper definition is not
      # in one of Rails' standard load paths:
      #   helper :foo             # => requires 'foo_helper' and includes FooHelper
      #   helper 'resources/foo'  # => requires 'resources/foo_helper' and includes Resources::FooHelper
      #
      # When the argument is a +Module+, it will be included directly in the template class.
      #   helper FooHelper # => includes FooHelper
      #
      # When the argument is the symbol <tt>:all</tt>, the controller will includes all helpers from 
      # <tt>app/views/helpers/**/*.rb</tt> under +RAILS_ROOT+.
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

      # Declare a controller method as a helper. For example, the following
      # makes the +current_user+ controller method available to the view:
      #   class ApplicationController < ActionController::Base
      #     helper_method :current_user
      #     def current_user
      #       @current_user ||= User.find(session[:user])
      #     end
      #   end
      def helper_method(*methods)
        methods.flatten.each do |method|
          master_helper_module.module_eval <<-end_eval
            def #{method}(*args, &block)
              controller.send(%(#{method}), *args, &block)
            end
          end_eval
        end
      end

      # Declares helper accessors for controller attributes. For example, the
      # following adds new +name+ and <tt>name=</tt> instance methods to a
      # controller and makes them available to the view:
      #   helper_attr :name
      #   attr_accessor :name
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end


      private
        def default_helper_module!
          module_name = name.sub(/Controller$|$/, 'Helper')
          module_path = module_name.split('::').map { |m| m.underscore }.join('/')
          require_dependency module_path
          helper module_name.constantize
        rescue MissingSourceFile => e
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