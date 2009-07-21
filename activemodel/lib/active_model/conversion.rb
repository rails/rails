module ActiveModel
  # Include ActiveModel::Conversion if your object "acts like an ActiveModel model".
  module Conversion
    def to_model
      self
    end
  end
end
