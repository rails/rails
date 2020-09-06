# frozen_string_literal: true

class Owner < ActiveRecord::Base
  self.primary_key = :owner_id
  has_many :pets, -> { order 'pets.name desc' }
  has_many :toys, through: :pets
  has_many :persons, through: :pets

  belongs_to :last_pet, class_name: 'Pet'
  scope :including_last_pet, -> {
    select('
      owners.*, (
        select p.pet_id from pets p
        where p.owner_id = owners.owner_id
        order by p.name desc
        limit 1
      ) as last_pet_id
    ').includes(:last_pet)
  }

  after_commit :execute_blocks

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
end
