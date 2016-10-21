module ActiveRecord
  module Type
    Value = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("ActiveRecord::Type::Value", "ActiveModel::Type::Value")
  end
end
