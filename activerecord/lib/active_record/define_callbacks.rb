module ActiveRecord
  # This module exists because `ActiveRecord::AttributeMethods::Dirty` needs to
  # define callbacks, but continue to have its version of `save` be the super
  # method of `ActiveRecord::Callbacks`. This will be removed when the removal
  # of deprecated code removes this need.
  module DefineCallbacks
    extend ActiveSupport::Concern

    module ClassMethods # :nodoc:
      include ActiveModel::Callbacks
    end

    included do
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :initialize, :find, :touch, only: :after
      define_model_callbacks :save, :create, :update, :destroy
    end
  end
end
