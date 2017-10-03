# frozen_string_literal: true

class Guitar < ActiveRecord::Base
  belongs_to :manufacturer, class_name: "Company", foreign_key: "company_id"
  belongs_to :player, class_name: "Person", foreign_key: "person_id"
  has_many :tuning_pegs, index_errors: true
  accepts_nested_attributes_for :tuning_pegs
end
