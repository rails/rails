# frozen_string_literal: true

# :markup: markdown

class ActiveStorage::Attached::Builder # :nodoc:
  autoload :ActiveRecordOwner, "active_storage/attached/builder/active_record_owner"
  autoload :Generic, "active_storage/attached/builder/generic"

  def self.for(model)
    if active_record_owner?(model)
      ActiveRecordOwner.new(model)
    else
      Generic.new(model)
    end
  end

  def self.active_record_owner?(model)
    defined?(::ActiveRecord::Base) && !::ActiveRecord.autoload?(:Base) && model < ::ActiveRecord::Base
  end
end
