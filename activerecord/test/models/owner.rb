class Owner < ActiveRecord::Base
  self.primary_key = :owner_id
  has_many :pets, -> { order 'pets.name desc' }
  has_many :toys, :through => :pets

  belongs_to :last_pet, class_name: 'Pet'
  scope :including_last_pet, -> {
    select(%q[
      owners.*, (
        select p.pet_id from pets p
        where p.owner_id = owners.owner_id
        order by p.name desc
        limit 1
      ) as last_pet_id
    ]).includes(:last_pet)
  }

  after_commit :execute_blocks
  after_touch :after_touch_callback

  accepts_nested_attributes_for :pets, allow_destroy: true

  def blocks
    @blocks ||= []
  end

  def on_after_commit(&block)
    blocks << block
  end

  def execute_blocks
    blocks.each do |block|
      block.call(self)
    end
    @blocks = []
  end

  # For tracking the number of after_touch callbacks across instances.
  def after_touch_callback
    @@after_touch_callbacks ||= 0
    @@after_touch_callbacks = @@after_touch_callbacks + 1
  end

  def self.reset_touch_callbacks
    @@after_touch_callbacks = 0
  end

  def self.after_touch_callbacks
    @@after_touch_callbacks
  end
end
