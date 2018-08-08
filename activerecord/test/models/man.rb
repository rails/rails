# frozen_string_literal: true

class Man < ActiveRecord::Base
  has_one :face, inverse_of: :man
  has_one :polymorphic_face, class_name: "Face", as: :polymorphic_man, inverse_of: :polymorphic_man
  has_one :polymorphic_face_without_inverse, class_name: "Face", as: :poly_man_without_inverse
  has_many :interests, inverse_of: :man
  has_many :polymorphic_interests, class_name: "Interest", as: :polymorphic_man, inverse_of: :polymorphic_man
  # These are "broken" inverse_of associations for the purposes of testing
  has_one :dirty_face, class_name: "Face", inverse_of: :dirty_man
  has_many :secret_interests, class_name: "Interest", inverse_of: :secret_man
  has_one :mixed_case_monkey
end

class Human < Man
end
