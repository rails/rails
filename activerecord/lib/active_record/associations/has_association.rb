module ActiveRecord
  module Associations
    # Included in all has_* associations (i.e. everything except belongs_to)
    module HasAssociation #:nodoc:
      protected
        # Sets the owner attributes on the given record
        def set_owner_attributes(record)
          if @owner.persisted?
            construct_owner_attributes.each { |key, value| record[key] = value }
          end
        end
    end
  end
end
