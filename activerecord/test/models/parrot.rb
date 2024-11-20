# frozen_string_literal: true

class Parrot < ActiveRecord::Base
  self.inheritance_column = :parrot_sti_class

  has_and_belongs_to_many :pirates
  has_and_belongs_to_many :treasures
  has_many :loots, as: :looter, class_name: "Treasure"
  alias_attribute :title, :name

  validates_presence_of :name

  attribute :cancel_save_from_callback
  before_save :cancel_save_callback_method, if: :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end

  before_update :increment_updated_count
  def increment_updated_count
    self.updated_count += 1
  end

  def self.delete_all(*)
    with_connection do |c|
      c.delete("DELETE FROM parrots_pirates")
      c.delete("DELETE FROM parrots_treasures")
    end
    super
  end
end

class LiveParrot < Parrot
  enum :breed, { african: 0, australian: 1 }
end

class DeadParrot < Parrot
  belongs_to :killer, class_name: "Pirate", foreign_key: :killer_id
end
