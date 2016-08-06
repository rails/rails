class Parrot < ActiveRecord::Base
  self.inheritance_column = :parrot_sti_class

  has_and_belongs_to_many :pirates
  has_and_belongs_to_many :treasures
  has_many :loots, :as => :looter
  alias_attribute :title, :name

  validates_presence_of :name

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, :if => :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end
end

class LiveParrot < Parrot
end

class DeadParrot < Parrot
  belongs_to :killer, :class_name => "Pirate", foreign_key: :killer_id
end
