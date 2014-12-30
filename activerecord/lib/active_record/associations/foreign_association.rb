module ActiveRecord::Associations
  module ForeignAssociation
    def foreign_key_present?
      if reflection.klass.primary_key
        owner.attribute_present?(reflection.active_record_primary_key)
      else
        false
      end
    end
  end
end
