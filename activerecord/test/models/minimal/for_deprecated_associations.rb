  # Minimal models for isolation, persisted in the existing tables.
  #
  # DATS = Deprecated Assciations Test Suite.
  module DATS
    def self.table_name_prefix
      ''
    end

    class Car < ActiveRecord::Base
      self.lock_optimistically = false

      has_many :tyres, class_name: "#{DATS}::Tyre", dependent: :destroy
      has_many :deprecated_tyres, class_name: "#{DATS}::Tyre", dependent: :destroy, deprecated: true

      accepts_nested_attributes_for :tyres, :deprecated_tyres

      has_one :bulb, class_name: "#{DATS}::Bulb", dependent: :destroy
      has_one :deprecated_bulb, class_name: "#{DATS}::Bulb", dependent: :destroy, deprecated: true

      accepts_nested_attributes_for :bulb, :deprecated_bulb
    end

    class Tyre < ActiveRecord::Base
    end

    class Bulb < ActiveRecord::Base
      belongs_to :car, class_name: "#{DATS}::Car", dependent: :destroy, touch: true
      belongs_to :deprecated_car, class_name: "#{DATS}::Car", foreign_key: "car_id", dependent: :destroy, touch: true, deprecated: true
    end
  end
