# frozen_string_literal: true

class MARC::Record < ActiveRecord::Base
  class Field
    class Subfield
      include ActiveModel::Embedding::Document

      attribute :code, :string
      attribute :value, :string

      validates :code, presence: true, format: { with: /\w/ }
    end

    include ActiveModel::Embedding::Document

    attribute :tag, :string
    attribute :value, :string
    attribute :indicator1, :string, default: " "
    attribute :indicator2, :string, default: " "

    embeds_many :subfields

    validates :tag, presence: true, format: { with: /\d{3}/ }

    validates :subfields, presence: true, unless: :control_field?
    validates_associated :subfields, unless: :control_field?

    def attributes
      if control_field?
        {
          "id" => id,
          "tag" => tag,
          "value" => value
        }
      else
        {
          "id" => id,
          "tag" => tag,
          "indicator1" => indicator1,
          "indicator2" => indicator2,
          "subfields" => subfields,
        }
      end
    end

    def control_field?
      /00\d/ === tag
    end

    # Yet another Hash-like reader method
    def [](code)
      occurrences = subfields.select { |subfield| subfield.code == code }
      occurrences.first unless occurrences.count > 1
    end
  end

  include ActiveModel::Embedding::Associations

  embeds_many :fields

  validates :fields, presence: true
  validates_associated :fields

  # Hash-like reader method
  def [](tag)
    occurrences = fields.select { |field| field.tag == tag }
    occurrences.first unless occurrences.count > 1
  end
end
