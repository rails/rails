# frozen_string_literal: true

class Face < ActiveRecord::Base
  belongs_to :man, inverse_of: :face
  belongs_to :human, polymorphic: true
  belongs_to :polymorphic_man, polymorphic: true, inverse_of: :polymorphic_face
  # Oracle identifier length is limited to 30 bytes or less, `polymorphic` renamed `poly`
  belongs_to :poly_man_without_inverse, polymorphic: true
  # These is a "broken" inverse_of for the purposes of testing
  belongs_to :horrible_man, class_name: "Man", inverse_of: :horrible_face
  belongs_to :horrible_polymorphic_man, polymorphic: true, inverse_of: :horrible_polymorphic_face

  validate do
    man
  end
end
