# frozen_string_literal: true

module ActionController
  module ExecutionContext # :nodoc:
    private
      def process_action(*)
        ActiveSupport::Executor.set_context(controller: self) { super }
      end
  end
end
