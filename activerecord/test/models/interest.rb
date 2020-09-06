# frozen_string_literal: true

class Interest < ActiveRecord::Base
  belongs_to :human, inverse_of: :interests
  belongs_to :human_with_callbacks,
    class_name: 'Human',
    foreign_key: :human_id,
    inverse_of: :interests_with_callbacks
  belongs_to :polymorphic_human, polymorphic: true, inverse_of: :polymorphic_interests
  belongs_to :polymorphic_human_with_callbacks,
    foreign_key: :polymorphic_human_id,
    foreign_type: :polymorphic_human_type,
    polymorphic: true,
    inverse_of: :polymorphic_interests_with_callbacks
  belongs_to :zine, inverse_of: :interests
end
