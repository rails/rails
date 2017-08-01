# frozen_string_literal: true

module ActiveRecord
  module Type
    class Date < ActiveModel::Type::Date
      include Internal::Timezone
    end
  end
end
