# frozen_string_literal: true

class Aircraft
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :manufactured_at, :datetime, default: -> { Time.current }
  attribute :name, :string
  attribute :wheels_count, :integer, default: 0
  attribute :wheels_owned_at, :datetime
end
