# frozen_string_literal: true

class Pirate < ActiveRecord::Base
  belongs_to :parrot, validate: true
  belongs_to :non_validated_parrot, class_name: "Parrot"
  has_and_belongs_to_many :parrots, -> { order("parrots.id ASC") }, validate: true
  has_and_belongs_to_many :non_validated_parrots, class_name: "Parrot"
  has_and_belongs_to_many :parrots_with_method_callbacks, class_name: "Parrot",
    before_add: :log_before_add,
    after_add: :log_after_add,
    before_remove: :log_before_remove,
    after_remove: :log_after_remove
  has_and_belongs_to_many :parrots_with_proc_callbacks, class_name: "Parrot",
    before_add: proc { |p, pa| p.ship_log << "before_adding_proc_parrot_#{pa.id || '<new>'}" },
    after_add: proc { |p, pa| p.ship_log << "after_adding_proc_parrot_#{pa.id || '<new>'}" },
    before_remove: proc { |p, pa| p.ship_log << "before_removing_proc_parrot_#{pa.id}" },
    after_remove: proc { |p, pa| p.ship_log << "after_removing_proc_parrot_#{pa.id}" }
  has_and_belongs_to_many :autosaved_parrots, class_name: "Parrot", autosave: true

  module PostTreasuresExtension
    def build(attributes = {})
      super({ name: "from extension" }.merge(attributes))
    end
  end

  has_many :treasures, as: :looter, extend: PostTreasuresExtension
  has_many :treasure_estimates, through: :treasures, source: :price_estimates

  has_one :ship
  has_one :update_only_ship, class_name: "Ship"
  has_one :non_validated_ship, class_name: "Ship"
  has_many :birds, -> { order("birds.id ASC") }
  has_many :birds_with_method_callbacks, class_name: "Bird",
    before_add: :log_before_add,
    after_add: :log_after_add,
    before_remove: :log_before_remove,
    after_remove: :log_after_remove
  has_many :birds_with_proc_callbacks, class_name: "Bird",
    before_add: proc { |p, b| p.ship_log << "before_adding_proc_bird_#{b.id || '<new>'}" },
    after_add: proc { |p, b| p.ship_log << "after_adding_proc_bird_#{b.id || '<new>'}" },
    before_remove: proc { |p, b| p.ship_log << "before_removing_proc_bird_#{b.id}" },
    after_remove: proc { |p, b| p.ship_log << "after_removing_proc_bird_#{b.id}" }
  has_many :birds_with_reject_all_blank, class_name: "Bird"

  has_one :foo_bulb, -> { where name: "foo" }, foreign_key: :car_id, class_name: "Bulb"

  accepts_nested_attributes_for :parrots, :birds, allow_destroy: true, reject_if: proc(&:empty?)
  accepts_nested_attributes_for :ship, allow_destroy: true, reject_if: proc(&:empty?)
  accepts_nested_attributes_for :update_only_ship, update_only: true
  accepts_nested_attributes_for :parrots_with_method_callbacks, :parrots_with_proc_callbacks,
    :birds_with_method_callbacks, :birds_with_proc_callbacks, allow_destroy: true
  accepts_nested_attributes_for :birds_with_reject_all_blank, reject_if: :all_blank

  validates_presence_of :catchphrase

  def ship_log
    @ship_log ||= []
  end

  def reject_empty_ships_on_create(attributes)
    attributes.delete("_reject_me_if_new").present? && !persisted?
  end

  attr_accessor :cancel_save_from_callback, :parrots_limit
  before_save :cancel_save_callback_method, if: :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end

  private
    def log_before_add(record)
      log(record, "before_adding_method")
    end

    def log_after_add(record)
      log(record, "after_adding_method")
    end

    def log_before_remove(record)
      log(record, "before_removing_method")
    end

    def log_after_remove(record)
      log(record, "after_removing_method")
    end

    def log(record, callback)
      ship_log << "#{callback}_#{record.class.name.downcase}_#{record.id || '<new>'}"
    end
end

class DestructivePirate < Pirate
  has_one :dependent_ship, class_name: "Ship", foreign_key: :pirate_id, dependent: :destroy
end

class FamousPirate < ActiveRecord::Base
  self.table_name = "pirates"
  has_many :famous_ships, inverse_of: :famous_pirate, foreign_key: :pirate_id
  validates_presence_of :catchphrase, on: :conference
end

class SpacePirate < ActiveRecord::Base
  self.table_name = "pirates"

  belongs_to :parrot
  belongs_to :parrot_with_annotation, -> { annotate("that tells jokes") }, class_name: :Parrot, foreign_key: :parrot_id
  has_and_belongs_to_many :parrots, foreign_key: :pirate_id
  has_and_belongs_to_many :parrots_with_annotation, -> { annotate("that are very colorful") }, class_name: :Parrot, foreign_key: :pirate_id
  has_one :ship, foreign_key: :pirate_id
  has_one :ship_with_annotation, -> { annotate("that is a rocket") }, class_name: :Ship, foreign_key: :pirate_id
  has_many :birds, foreign_key: :pirate_id
  has_many :birds_with_annotation, -> { annotate("that are also parrots") }, class_name: :Bird, foreign_key: :pirate_id
  has_many :treasures, as: :looter
  has_many :treasure_estimates, through: :treasures, source: :price_estimates
  has_many :treasure_estimates_with_annotation, -> { annotate("yarrr") }, through: :treasures, source: :price_estimates
end
