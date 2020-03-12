# frozen_string_literal: true

class Lounge < ActiveRecord::Base
  belongs_to :house, :optional => true

  before_validation :max_two_purple

  scope :purple, -> { where(:colour => "purple") }
  scope :red, -> { where(:colour => "red") }
  LARGE_CLAUSE = "size > 25"
  scope :large, -> { where(LARGE_CLAUSE) }
  scope :humongous, -> { where("size > 70") }

  @@last_before_validation_query = ""

  def self.last_before_validation_query
    @@last_before_validation_query
  end

  private

  def max_two_purple
    unrelated_scope = Lounge.unscoped { house.lounges.humongous.red }

    Lounge.unscoped do
      @@last_before_validation_query = unrelated_scope.purple.to_sql
      errors.add(:colour, "Sorry, only two purple lounges are allowed") if Lounge.purple.count > 2
    end
  end
end