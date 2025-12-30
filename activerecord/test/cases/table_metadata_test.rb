# frozen_string_literal: true

require "cases/helper"
require "models/developer"

module ActiveRecord
  class TableMetadataTest < ActiveSupport::TestCase
    test "#associated_table creates the right type caster for joined table with different association name" do
      base_table_metadata = TableMetadata.new(AuditRequiredDeveloper, Arel::Table.new("developers"))

      associated_table_metadata = base_table_metadata.associated_table("audit_logs")

      assert_equal ActiveRecord::Type::String, associated_table_metadata.arel_table.type_for_attribute(:message).class
    end
  end
end
