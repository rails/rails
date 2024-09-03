# frozen_string_literal: true

class Chef < ActiveRecord::Base
  belongs_to :employable, polymorphic: true
  has_many :recipes
end

class ChefList < Chef
  belongs_to :employable_list, polymorphic: true
end

class ChefWithPolymorphicInverseOf < Chef
  attr_reader :before_validation_callbacks_counter
  attr_reader :before_create_callbacks_counter
  attr_reader :before_save_callbacks_counter

  attr_reader :after_validation_callbacks_counter
  attr_reader :after_create_callbacks_counter
  attr_reader :after_save_callbacks_counter

  belongs_to :employable, polymorphic: true, inverse_of: :chef
  accepts_nested_attributes_for :employable

  before_validation :update_before_validation_counter
  before_create :update_before_create_counter
  before_save :update_before_save_counter

  after_validation :update_after_validation_counter
  after_create :update_after_create_counter
  after_save :update_after_save_counter

  private
    def update_before_validation_counter
      @before_validation_callbacks_counter ||= 0
      @before_validation_callbacks_counter += 1
    end

    def update_before_create_counter
      @before_create_callbacks_counter ||= 0
      @before_create_callbacks_counter += 1
    end

    def update_before_save_counter
      @before_save_callbacks_counter ||= 0
      @before_save_callbacks_counter += 1
    end

    def update_after_validation_counter
      @after_validation_callbacks_counter ||= 0
      @after_validation_callbacks_counter += 1
    end

    def update_after_create_counter
      @after_create_callbacks_counter ||= 0
      @after_create_callbacks_counter += 1
    end

    def update_after_save_counter
      @after_save_callbacks_counter ||= 0
      @after_save_callbacks_counter += 1
    end
end
