# frozen_string_literal: true

class Interest < ActiveRecord::Base
  belongs_to :man, inverse_of: :interests
  belongs_to :man_with_callbacks,
    class_name: "Man",
    foreign_key: :man_id,
    inverse_of: :interests_with_callbacks
  belongs_to :polymorphic_man, polymorphic: true, inverse_of: :polymorphic_interests
  belongs_to :polymorphic_man_with_callbacks,
    foreign_key: :polymorphic_man_id,
    foreign_type: :polymorphic_man_type,
    polymorphic: true,
    inverse_of: :polymorphic_interests_with_callbacks
  belongs_to :zine, inverse_of: :interests
end
