module AbstractController
  module Helpers
    extend ActiveSupport::Concern

    include RenderingController

    def self.next_serial
      @helper_serial ||= 0
      @helper_serial += 1
    end

    included do
      extlib_inheritable_accessor(:_helpers) { Module.new }
      extlib_inheritable_accessor(:_helper_serial) do
        AbstractController::Helpers.next_serial
      end
    end

    module ClassMethods
      # When a class is inherited, wrap its helper module in a new module.
      # This ensures that the parent class's module can be changed
      # independently of the child class's.
      def inherited(klass)
        helpers = _helpers
        klass._helpers = Module.new { include helpers }

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

      # Make a number of helper modules part of this class' default
      # helpers.
      #
      # ==== Parameters
      # *args<Array[Module]>:: Modules to be included
      # block<Block>:: Evalulate the block in the context
      #   of the helper module. Any methods defined in the block
      #   will be helpers.
      def helper(*args, &block)
        self._helper_serial = AbstractController::Helpers.next_serial + 1

        args.flatten.each do |arg|
          case arg
          when Module
            add_template_helper(arg)
          end
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
    end
  end
end
