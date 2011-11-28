module ActiveModel
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializable

    included do
      ActiveSupport::Deprecation.warn "ActiveModel::Serialization is deprecated in favor of ActiveModel::Serializable"
    end
  end
end