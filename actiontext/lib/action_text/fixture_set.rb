# frozen_string_literal: true

module ActionText
  class FixtureSet
    def self.attachment(fixture_set_name, label, column_type: :integer)
      signed_global_id = ActiveRecord::FixtureSet.signed_global_id fixture_set_name, label,
        column_type: column_type, for: ActionText::Attachable::LOCATOR_NAME

      %(<action-text-attachment sgid="#{signed_global_id}"></action-text-attachment>)
    end
  end
end
