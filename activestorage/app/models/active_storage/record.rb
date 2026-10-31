# frozen_string_literal: true

class ActiveStorage::Record < ActiveRecord::Base # :nodoc:
  self.abstract_class = true
end

ActiveSupport.run_load_hooks :active_storage_record, ActiveStorage::Record
