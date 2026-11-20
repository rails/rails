# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module Deduplicable
      extend ActiveSupport::Concern

      module ClassMethods
        def registry
          registries = ActiveSupport::Ractors.store_if_absent(:active_record_deduplicable_registries) { {} }
          registries[self] ||= {}
        end

        def new(*, **)
          super.deduplicate
        end
      end

      def deduplicate
        self.class.registry[self] ||= frozen? ? self : deduplicated
      end
      alias :-@ :deduplicate

      private
        def deduplicated
          freeze
        end
    end
  end
end
