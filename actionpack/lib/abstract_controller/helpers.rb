# frozen_string_literal: true

# :markup: markdown

require "active_support/dependencies"
require "active_support/core_ext/name_error"

module AbstractController
  module Helpers
    extend ActiveSupport::Concern

    included do
      class_attribute :_helper_methods, default: Array.new

      # This is here so that it is always higher in the inheritance chain than the
      # definition in lib/action_view/rendering.rb
      redefine_singleton_method(:_helpers) do
        if @_helpers ||= nil
          @_helpers
        else
          superclass._helpers
        end
      end

      self._helpers = define_helpers_module(self)
    end

    def _helpers
      self.class._helpers
    end

    module Resolution # :nodoc:
      def modules_for_helpers(modules_or_helper_prefixes)
        modules_or_helper_prefixes.flatten.map! do |module_or_helper_prefix|
          case module_or_helper_prefix
          when Module
            module_or_helper_prefix
          when String, Symbol
            helper_prefix = module_or_helper_prefix.to_s
            helper_prefix = helper_prefix.camelize unless helper_prefix.start_with?(/[A-Z]/)
            "#{helper_prefix}Helper".constantize
          else
            raise ArgumentError, "helper must be a String, Symbol, or Module"
          end
        end
      end

      def all_helpers_from_path(path)
        helpers = Array(path).flat_map do |_path|
          names = Dir["#{_path}/**/*_helper.rb"].map { |file| file[_path.to_s.size + 1..-"_helper.rb".size - 1] }
          names.sort!
        end
        helpers.uniq!
        helpers
      end

      def helper_modules_from_paths(paths)
        modules_for_helpers(all_helpers_from_path(paths))
      end
    end

    extend Resolution

    module ClassMethods
      # When a class is inherited, wrap its helper module in a new module. This
      # ensures that the parent class's module can be changed independently of the
      # child class's.
      def inherited(klass)
        # Inherited from parent by default
        klass._helpers = nil

        klass.class_eval { default_helper_module! } unless klass.anonymous?
        super
      end

      attr_writer :_helpers

      include Resolution

      ##
      # :method: modules_for_helpers
      # :call-seq: modules_for_helpers(modules_or_helper_prefixes)
      #
      # Given an array of values like the ones accepted by `helper`, this method
      # returns an array with the corresponding modules, in the same order.
      #
      #     ActionController::Base.modules_for_helpers(["application", "chart", "rubygems"])
      #     # => [ApplicationHelper, ChartHelper, RubygemsHelper]
      #
      #--
      # Implemented by Resolution#modules_for_helpers.

      # :method: # all_helpers_from_path
      # :call-seq: all_helpers_from_path(path)
      #
      # Returns a list of helper names in a given path.
      #
      #     ActionController::Base.all_helpers_from_path 'app/helpers'
      #     # => ["application", "chart", "rubygems"]
      #
      #--
      # Implemented by Resolution#all_helpers_from_path.

      # Declare a controller method as a helper. For example, the following
      # makes the `current_user` and `logged_in?` controller methods available
      # to the view:
      #
      #     class ApplicationController < ActionController::Base
      #       helper_method :current_user, :logged_in?
      #
      #       private
      #         def current_user
      #           @current_user ||= User.find_by(id: session[:user])
      #         end
      #
      #         def logged_in?
      #           current_user != nil
      #         end
      #     end
      #
      # In a view:
      #
      #     <% if logged_in? -%>Welcome, <%= current_user.name %><% end -%>
      #
      # #### Parameters
      # *   `method[, method]` - A name or names of a method on the controller to be
      #     made available on the view.
      def helper_method(*methods)
        methods.flatten!
        self._helper_methods += methods

        location = caller_locations(1, 1).first
        file, line = location.path, location.lineno

        methods.each do |method|
          # def current_user(...)
          #   controller.send(:'current_user', ...)
          # end
          _helpers_for_modification.class_eval <<~ruby_eval.lines.map(&:strip).join(";"), file, line
            def #{method}(...)
              controller.send(:'#{method}', ...)
            end
          ruby_eval
        end
      end

      # Includes the given modules in the template class.
      #
      # Modules can be specified in different ways. All of the following calls include
      # `FooHelper`:
      #
      #     # Module, recommended.
      #     helper FooHelper
      #
      #     # String/symbol without the "helper" suffix, camel or snake case.
      #     helper "Foo"
      #     helper :Foo
      #     helper "foo"
      #     helper :foo
      #
      # The last two assume that `"foo".camelize` returns "Foo".
      #
      # When strings or symbols are passed, the method finds the actual module object
      # using String#constantize. Therefore, if the module has not been yet loaded, it
      # has to be autoloadable, which is normally the case.
      #
      # Namespaces are supported. The following calls include `Foo::BarHelper`:
      #
      #     # Module, recommended.
      #     helper Foo::BarHelper
      #
      #     # String/symbol without the "helper" suffix, camel or snake case.
      #     helper "Foo::Bar"
      #     helper :"Foo::Bar"
      #     helper "foo/bar"
      #     helper :"foo/bar"
      #
      # The last two assume that `"foo/bar".camelize` returns "Foo::Bar".
      #
      # The method accepts a block too. If present, the block is evaluated in the
      # context of the controller helper module. This simple call makes the `wadus`
      # method available in templates of the enclosing controller:
      #
      #     helper do
      #       def wadus
      #         "wadus"
      #       end
      #     end
      #
      # Furthermore, all the above styles can be mixed together:
      #
      #     helper FooHelper, "woo", "bar/baz" do
      #       def wadus
      #         "wadus"
      #       end
      #     end
      #
      def helper(*args, &block)
        modules_for_helpers(args).each do |mod|
          next if _helpers.include?(mod)
          _helpers_for_modification.include(mod)
        end

        _helpers_for_modification.module_eval(&block) if block_given?
      end

      # Clears up all existing helpers in this class, only keeping the helper with the
      # same name as this class.
      def clear_helpers
        inherited_helper_methods = _helper_methods
        self._helpers = Module.new
        self._helper_methods = Array.new

        inherited_helper_methods.each { |meth| helper_method meth }
        default_helper_module! unless anonymous?
      end

      def _helpers_for_modification
        unless @_helpers
          self._helpers = define_helpers_module(self, superclass._helpers)
        end
        _helpers
      end

      private
        def define_helpers_module(klass, helpers = nil)
          # In some tests inherited is called explicitly. In that case, just return the
          # module from the first time it was defined
          return klass.const_get(:HelperMethods) if klass.const_defined?(:HelperMethods, false)

          mod = Module.new
          klass.const_set(:HelperMethods, mod)
          mod.include(helpers) if helpers
          mod
        end

        def default_helper_module!
          helper_prefix = name.delete_suffix("Controller")
          helper(helper_prefix)
        rescue NameError => e
          raise unless e.missing_name?("#{helper_prefix}Helper")
        end
    end
  end
end
