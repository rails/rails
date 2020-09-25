# frozen_string_literal: true

module ActionText
  class FixtureSet
    def self.attachment(fixture_set_name, label)
      identifier = ActiveRecord::FixtureSet.identify(label)
      model_name = ActiveRecord::FixtureSet.default_fixture_model_name(fixture_set_name)
      uri = URI::GID.build(app: GlobalID.app, model_name: model_name, model_id: identifier)
      signed_global_id = SignedGlobalID.new(uri, for: ActionText::Attachable::LOCATOR_NAME)

      %(<action-text-attachment sgid="#{signed_global_id}"></action-text-attachment)
    end
  end
end
