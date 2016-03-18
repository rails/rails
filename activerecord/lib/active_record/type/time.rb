module ActiveRecord
  module Type
    class Time < ActiveModel::Type::Time
      include Internal::Timezone
    end
  end
end

