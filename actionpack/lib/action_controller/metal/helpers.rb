require 'active_support/dependencies'

module ActionController
  # The Rails framework provides a large number of helpers for working with +assets+, +dates+, +forms+,
  # +numbers+ and model objects, to name a few. These helpers are available to all templates
  # by default.
  #
  # In addition to using the standard template helpers provided in the Rails framework, creating custom helpers to
  # extract complicated logic or reusable functionality is strongly encouraged. By default, the controller will
  # include a helper whose name matches that of the controller, e.g., <tt>MyController</tt> will automatically
  # include <tt>MyHelper</tt>.
  #
  # Additional helpers can be specified using the +helper+ class method in <tt>ActionController::Base</tt> or any
  # controller which inherits from it.
  #
  # ==== Examples
  # The +to_s+ method from the Time class can be wrapped in a helper method to display a custom message if
  # the Time object is blank:
  #
  #   module FormattedTimeHelper
  #     def format_time(time, format=:long, blank_message="&nbsp;")
  #       time.blank? ? blank_message : time.to_s(format)
  #     end
  #   end
  #
  # FormattedTimeHelper can now be included in a controller, using the +helper+ class method:
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
  module Helpers
    extend ActiveSupport::Concern

    include AbstractController::Helpers

    included do
      # Set the default directory for helpers
      extlib_inheritable_accessor(:helpers_dir) do
        defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/app/helpers" : "app/helpers"
      end
    end

    module ClassMethods
      def inherited(klass)
        klass.class_eval { default_helper_module! unless name.blank? }
        super
      end

      # The +helper+ class method can take a series of helper module names, a block, or both.
      #
      # ==== Parameters
      # *args<Array[Module, Symbol, String, :all]>
      # block<Block>:: A block defining helper methods
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
        super(*_modules_for_helpers(args), &block)
      end

      # Declares helper accessors for controller attributes. For example, the
      # following adds new +name+ and <tt>name=</tt> instance methods to a
      # controller and makes them available to the view:
      #   helper_attr :name
      #   attr_accessor :name
      #
      # ==== Parameters
      # *attrs<Array[String, Symbol]>:: Names of attributes to be converted
      #   into helpers.
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end

      # Provides a proxy to access helpers methods from outside the view.
      def helpers
        @helper_proxy ||= ActionView::Base.new.extend(_helpers)
      end

    private
      # Returns a list of modules, normalized from the acceptable kinds of
      # helpers with the following behavior:
      # String or Symbol:: :FooBar or "FooBar" becomes "foo_bar_helper",
      #   and "foo_bar_helper.rb" is loaded using require_dependency.
      # :all:: Loads all modules in the #helpers_dir
      # Module:: No further processing
      #
      # After loading the appropriate files, the corresponding modules
      # are returned.
      #
      # ==== Parameters
      # args<Array[String, Symbol, Module, all]>:: A list of helpers
      #
      # ==== Returns
      # Array[Module]:: A normalized list of modules for the list of
      #   helpers provided.
      def _modules_for_helpers(args)
        args.flatten.map! do |arg|
          case arg
          when :all
            _modules_for_helpers all_application_helpers
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
        raise e unless e.is_missing? "#{module_path}_helper"
      rescue NameError => e
        raise e unless e.missing_name? "#{module_name}Helper"
      end

      # Extract helper names from files in app/helpers/**/*.rb
      def all_application_helpers
        extract = /^#{Regexp.quote(helpers_dir)}\/?(.*)_helper.rb$/
        Dir["#{helpers_dir}/**/*_helper.rb"].map { |file| file.sub extract, '\1' }
      end
    end
  end
end
