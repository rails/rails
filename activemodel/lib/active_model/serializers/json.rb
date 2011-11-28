module ActiveModel
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Serializable::JSON

      included do
        ActiveSupport::Deprecation.warn "ActiveModel::Serializers::JSON is deprecated in favor of ActiveModel::Serializable::JSON"
      end
    end
  end
end