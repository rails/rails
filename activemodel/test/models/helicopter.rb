# frozen_string_literal: true

class Helicopter
  include ActiveModel::Conversion
end

class Helicopter::Comanche
  include ActiveModel::Conversion
end

class Helicopter::Apache
  include ActiveModel::Conversion

  class << self
    def model_name
      @model_name ||= ActiveModel::Name.new(self).tap do |model_name|
        model_name.collection = "attack_helicopters"
        model_name.element = "ah-64"
      end
    end
  end
end
