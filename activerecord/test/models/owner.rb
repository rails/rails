class Owner < ActiveRecord::Base
  self.primary_key = :owner_id
  has_many :pets
  has_many :toys, :through => :pets

  after_commit :execute_blocks

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
