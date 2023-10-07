# frozen_string_literal: true

class Face < ActiveRecord::Base
  belongs_to :human, inverse_of: :face, optional: true
  belongs_to :autosave_human, class_name: "Human", foreign_key: :human_id, inverse_of: :autosave_face, optional: true
  belongs_to :super_human, polymorphic: true, optional: true
  belongs_to :polymorphic_human, polymorphic: true, inverse_of: :polymorphic_face, optional: true
  # Oracle identifier length is limited to 30 bytes or less, `polymorphic` renamed `poly`
  belongs_to :poly_human_without_inverse, polymorphic: true, optional: true
  # These are "broken" inverse_of associations for the purposes of testing
  belongs_to :confused_human, class_name: "Human", inverse_of: :cnffused_face, optional: true
  belongs_to :puzzled_polymorphic_human, polymorphic: true, inverse_of: :puzzled_polymorphic_face, optional: true

  validate do
    human
  end
end
