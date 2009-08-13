module ActionController
  # ActionController::HideActions adds the ability to prevent public methods on a controller
  # to be called as actions.
  module HideActions
    extend ActiveSupport::Concern

    included do
      extlib_inheritable_accessor(:hidden_actions) { Set.new }
    end

  private

    # Overrides AbstractController::Base#action_method? to return false if the
    # action name is in the list of hidden actions.
    def action_method?(action_name)
      self.class.visible_action?(action_name) do
        !hidden_actions.include?(action_name) && super
      end
    end

    module ClassMethods
      # Sets all of the actions passed in as hidden actions.
      #
      # ==== Parameters
      # *args<#to_s>:: A list of actions
      def hide_action(*args)
        hidden_actions.merge(args.map! {|a| a.to_s })
      end

      def inherited(klass)
        klass.instance_variable_set("@visible_actions", {})
        super
      end

      def visible_action?(action_name)
        return @visible_actions[action_name] if @visible_actions.key?(action_name)
        @visible_actions[action_name] = yield
      end

      # Overrides AbstractController::Base#action_methods to remove any methods
      # that are listed as hidden methods.
      def action_methods
        @action_methods ||= Set.new(super.reject {|name| hidden_actions.include?(name)})
      end
    end
  end
end
