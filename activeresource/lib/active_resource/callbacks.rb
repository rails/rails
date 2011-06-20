require 'active_support/core_ext/array/wrap'

module ActiveResource
  module Callbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :before_validation, :after_validation, :before_save, :around_save, :after_save,
      :before_create, :around_create, :after_create, :before_update, :around_update,
      :after_update, :before_destroy, :around_destroy, :after_destroy
    ]

    included do
      extend ActiveModel::Callbacks
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :save, :create, :update, :destroy
    end
  end
end
