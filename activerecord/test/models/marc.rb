# frozen_string_literal: true

module MARC
  def self.table_name_prefix
    "marc_"
  end
end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "MARC"
end
