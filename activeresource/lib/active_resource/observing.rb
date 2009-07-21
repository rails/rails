module ActiveResource
  module Observing
    extend ActiveSupport::Concern
    include ActiveModel::Observing

    included do
      wrap_with_notifications :create, :save, :update, :destroy
    end
  end
end
