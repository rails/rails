require 'active_support/core_ext/class/attribute'

module ActionMailer
  # ActionController::HideActions adds the ability to prevent public methods on a controller
  # to be called as actions.
  module HideActions
    extend ActiveSupport::Concern

    included do
      class_attribute :hidden_actions
      self.hidden_actions = Set.new.freeze
    end

  private

    module ClassMethods
      # Sets all of the actions passed in as hidden actions.
      #
      # ==== Parameters
      # *args<#to_s>:: A list of actions
      def hide_action(*args)
        self.hidden_actions = hidden_actions.dup.merge(args.map(&:to_s)).freeze
      end

      # Run block and add all the new action_methods to hidden_actions.
      # This is used in inherited method.
      def with_hiding_actions
        yield
        clear_action_methods!
        hide_action(*action_methods)
        clear_action_methods!
      end

      def clear_action_methods!
        @action_methods = nil
      end

      # Overrides AbstractController::Base#action_methods to remove any methods
      # that are listed as hidden methods.
      def action_methods
        @action_methods ||= super.reject { |name| hidden_actions.include?(name) }
      end
    end
  end
end

