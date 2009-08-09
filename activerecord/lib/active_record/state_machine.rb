module ActiveRecord
  module StateMachine #:nodoc:
    extend ActiveSupport::Concern
    include ActiveModel::StateMachine

    included do
      before_validation :set_initial_state
      validates_presence_of :state
    end

    protected
      def write_state(state_machine, state)
        update_attributes! :state => state.to_s
      end

      def read_state(state_machine)
        self.state.to_sym
      end

      def set_initial_state
        self.state ||= self.class.state_machine.initial_state.to_s
      end
  end
end
