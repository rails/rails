# frozen_string_literal: true

class Human < ActiveRecord::Base
  self.table_name = "humans"

  has_one :face, inverse_of: :human
  has_one :autosave_face, class_name: "Face", autosave: true, foreign_key: :human_id, inverse_of: :autosave_human
  has_one :polymorphic_face, class_name: "Face", as: :polymorphic_human, inverse_of: :polymorphic_human
  has_one :polymorphic_face_without_inverse, class_name: "Face", as: :poly_human_without_inverse
  has_many :interests, inverse_of: :human
  has_many :interests_with_callbacks,
    class_name: "Interest",
    before_add: :add_called,
    after_add: :add_called,
    inverse_of: :human_with_callbacks
  has_many :polymorphic_interests,
    class_name: "Interest",
    as: :polymorphic_human,
    inverse_of: :polymorphic_human
  has_many :polymorphic_interests_with_callbacks,
    class_name: "Interest",
    as: :polymorphic_human,
    before_add: :add_called,
    after_add: :add_called,
    inverse_of: :polymorphic_human
  # These are "broken" inverse_of associations for the purposes of testing
  has_one :confused_face, class_name: "Face", inverse_of: :cnffused_human
  has_many :secret_interests, class_name: "Interest", inverse_of: :secret_human
  has_one :mixed_case_monkey

  attribute :add_callback_called, :boolean, default: false

  def add_called(_interest)
    self.add_callback_called = true
  end
end

class SuperHuman < Human
end
