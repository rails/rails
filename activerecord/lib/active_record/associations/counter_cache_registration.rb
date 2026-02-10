# frozen_string_literal: true

require "active_record/associations/counter_cache_registry"

module ActiveRecord
  module Associations
    # = Active Record Counter Cache Registration
    #
    # This module extends the inherited hook in ActiveRecord::Base to process
    # pending counter cache registrations when a new model class is defined.
    module CounterCacheRegistration
      extend ActiveSupport::Concern

      included do
        class << self
          alias_method :inherited_without_counter_cache_registration, :inherited

          def inherited(subclass)
            inherited_without_counter_cache_registration(subclass)

            CounterCacheRegistry.process_pending(subclass)
          end
        end
      end
    end
  end
end
