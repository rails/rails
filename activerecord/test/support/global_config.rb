# frozen_string_literal: true

module ARTest
  QUOTED_TYPE = ActiveRecord::Base.lease_connection.quote_column_name("type")

  module GlobalConfig
    def self.apply
      Thread.abort_on_exception = true

      ActiveRecord.deprecator.behavior = :raise
      ActiveModel.deprecator.behavior = :raise

      ActiveRecord.permanent_connection_checkout = :disallowed
      ActiveRecord::Delegation::DelegateCache.delegate_base_methods = false
      ActiveRecord::Relation.remove_method(:klass)
      I18n.enforce_available_locales = false

      ActiveRecord::Base.automatically_invert_plural_associations = true
      ActiveRecord.raise_on_assign_to_attr_readonly = true
      ActiveRecord.belongs_to_required_validates_foreign_key = false
      ActiveRecord.raise_on_missing_required_finder_order_columns = true
    end
  end
end
