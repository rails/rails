# frozen_string_literal: true

class ActiveStorage::Attached::Builder # :nodoc:
  autoload :ActiveRecordOwner, "active_storage/attached/builder/active_record_owner"
  autoload :Generic, "active_storage/attached/builder/generic"

  def self.for(model)
    if defined?(::ActiveRecord::Base) && model < ::ActiveRecord::Base
      ActiveRecordOwner.new(model)
    else
      Generic.new(model)
    end
  end
end
