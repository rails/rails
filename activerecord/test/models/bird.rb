# frozen_string_literal: true

class Bird < ActiveRecord::Base
  belongs_to :pirate
  validates_presence_of :name

  accepts_nested_attributes_for :pirate

  before_save do
    # force materialize_transactions
    self.class.lease_connection.materialize_transactions
  end

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, if: :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end

  attr_accessor :total_count, :enable_count
  after_initialize do
    self.total_count = Bird.count if enable_count
  end
end
