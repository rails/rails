# frozen_string_literal: true

class Face < ActiveRecord::Base
  belongs_to :human, inverse_of: :face
  belongs_to :super_human, polymorphic: true
  belongs_to :polymorphic_human, polymorphic: true, inverse_of: :polymorphic_face
  # Oracle identifier length is limited to 30 bytes or less, `polymorphic` renamed `poly`
  belongs_to :poly_human_without_inverse, polymorphic: true
  # These are "broken" inverse_of associations for the purposes of testing
  belongs_to :horrible_human, class_name: "Human", inverse_of: :horrible_face
  belongs_to :horrible_polymorphic_human, polymorphic: true, inverse_of: :horrible_polymorphic_face

  validate do
    human
  end
end
