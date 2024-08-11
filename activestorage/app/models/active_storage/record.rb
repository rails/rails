# frozen_string_literal: true

class ActiveStorage::Record < ActiveRecord::Base # :nodoc:
  self.abstract_class = true

  connects_to(**Rails.configuration.active_storage.connects_to) if Rails.configuration.active_storage.connects_to
end

ActiveSupport.run_load_hooks :active_storage_record, ActiveStorage::Record
