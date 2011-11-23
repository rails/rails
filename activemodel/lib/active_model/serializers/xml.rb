module ActiveModel
  module Serializers
    module Xml
      extend ActiveSupport::Concern
      include ActiveModel::Serializable::XML

      Serializer = ActiveModel::Serializable::XML::Serializer

      included do
        ActiveSupport::Deprecation.warn "ActiveModel::Serializers::Xml is deprecated in favor of ActiveModel::Serializable::XML"
      end
    end
  end
end