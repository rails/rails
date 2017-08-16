module AnotherApp
  class InteriorDesigner < ActiveRecord::Base
    has_one :chef, as: :employable

    def self.sti_name
      "InteriorDesigner"
    end
  end
end
