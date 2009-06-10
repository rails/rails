module ActionController
  # ActionController::HideActions adds the ability to prevent public methods on a controller
  # to be called as actions.
  module HideActions
    extend ActiveSupport::Concern

    included do
      extlib_inheritable_accessor(:hidden_actions) { Set.new }
    end

    def action_methods
      self.class.action_methods
    end

  private

    def action_method?(action_name)
      !hidden_actions.include?(action_name) && super
    end

    module ClassMethods
      # Sets
      def hide_action(*args)
        args.each do |arg|
          self.hidden_actions << arg.to_s
        end
      end

      def action_methods
        @action_methods ||= Set.new(super.reject {|name| self.hidden_actions.include?(name.to_s)})
      end
    end
  end
end
