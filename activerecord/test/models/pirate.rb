class Pirate < ActiveRecord::Base
  belongs_to :parrot, :validate => true
  belongs_to :non_validated_parrot, :class_name => 'Parrot'
  has_and_belongs_to_many :parrots, :validate => true
  has_and_belongs_to_many :non_validated_parrots, :class_name => 'Parrot'
  has_and_belongs_to_many :parrots_with_method_callbacks, :class_name => "Parrot",
    :before_add    => :log_before_add,
    :after_add     => :log_after_add,
    :before_remove => :log_before_remove,
    :after_remove  => :log_after_remove
  has_and_belongs_to_many :parrots_with_proc_callbacks, :class_name => "Parrot",
    :before_add    => proc {|p,pa| p.ship_log << "before_adding_proc_parrot_#{pa.id || '<new>'}"},
    :after_add     => proc {|p,pa| p.ship_log << "after_adding_proc_parrot_#{pa.id || '<new>'}"},
    :before_remove => proc {|p,pa| p.ship_log << "before_removing_proc_parrot_#{pa.id}"},
    :after_remove  => proc {|p,pa| p.ship_log << "after_removing_proc_parrot_#{pa.id}"}

  has_many :treasures, :as => :looter
  has_many :treasure_estimates, :through => :treasures, :source => :price_estimates

  # These both have :autosave enabled because accepts_nested_attributes_for is used on them.
  has_one :ship
  has_one :update_only_ship, :class_name => 'Ship'
  has_one :non_validated_ship, :class_name => 'Ship'
  has_many :birds
  has_many :birds_with_method_callbacks, :class_name => "Bird",
    :before_add    => :log_before_add,
    :after_add     => :log_after_add,
    :before_remove => :log_before_remove,
    :after_remove  => :log_after_remove
  has_many :birds_with_proc_callbacks, :class_name => "Bird",
    :before_add     => proc {|p,b| p.ship_log << "before_adding_proc_bird_#{b.id || '<new>'}"},
    :after_add      => proc {|p,b| p.ship_log << "after_adding_proc_bird_#{b.id || '<new>'}"},
    :before_remove  => proc {|p,b| p.ship_log << "before_removing_proc_bird_#{b.id}"},
    :after_remove   => proc {|p,b| p.ship_log << "after_removing_proc_bird_#{b.id}"}
  has_many :birds_with_reject_all_blank, :class_name => "Bird"

  accepts_nested_attributes_for :parrots, :birds, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }
  accepts_nested_attributes_for :ship, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }
  accepts_nested_attributes_for :update_only_ship, :update_only => true
  accepts_nested_attributes_for :parrots_with_method_callbacks, :parrots_with_proc_callbacks,
    :birds_with_method_callbacks, :birds_with_proc_callbacks, :allow_destroy => true
  accepts_nested_attributes_for :birds_with_reject_all_blank, :reject_if => :all_blank

  validates_presence_of :catchphrase

  def ship_log
    @ship_log ||= []
  end

  def reject_empty_ships_on_create(attributes)
    attributes.delete('_reject_me_if_new').present? && new_record?
  end

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, :if => :cancel_save_from_callback
  def cancel_save_callback_method
    false
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
