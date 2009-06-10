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
      !hidden_actions.include?(action_name) && super
    end

    module ClassMethods
      # Sets all of the actions passed in as hidden actions.
      #
      # ==== Parameters
      # *args<#to_s>:: A list of actions
      def hide_action(*args)
        hidden_actions.merge(args.map! {|a| a.to_s })
      end

      # Overrides AbstractController::Base#action_methods to remove any methods
      # that are listed as hidden methods.
      def action_methods
        @action_methods ||= Set.new(super.reject {|name| hidden_actions.include?(name)})
      end
    end
  end
end
