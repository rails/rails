
module ActionController
  # Adds the ability to prevent public methods on a controller to be called as actions.
  module HideActions
    extend ActiveSupport::Concern

    included do
      class_attribute :hidden_actions
      self.hidden_actions = Set.new.freeze
    end

  private

    # Overrides AbstractController::Base#action_method? to return false if the
    # action name is in the list of hidden actions.
    def method_for_action(action_name)
      self.class.visible_action?(action_name) && super
    end

    module ClassMethods
      # Sets all of the actions passed in as hidden actions.
      #
      # ==== Parameters
      # * <tt>args</tt> - A list of actions
      def hide_action(*args)
        self.hidden_actions = hidden_actions.dup.merge(args.map(&:to_s)).freeze
      end

      def visible_action?(action_name)
        not hidden_actions.include?(action_name)
      end

      # Overrides AbstractController::Base#action_methods to remove any methods
      # that are listed as hidden methods.
      def action_methods
        @action_methods ||= Set.new(super.reject { |name| hidden_actions.include?(name) }).freeze
      end
    end
  end
end
