# frozen_string_literal: true

module ActiveStorage
  record_superclass = Rails.application.config.active_storage.record_superclass&.constantize || ActiveRecord::Base

  klass = Class.new(record_superclass) do
    self.abstract_class = true
  end

  ActiveStorage.const_set "Record", klass

  ActiveSupport.run_load_hooks :active_storage_record, ActiveStorage::Record
end
