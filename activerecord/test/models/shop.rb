module Shop
  class Collection < ApplicationRecord
    has_many :products, :dependent => :nullify
  end

  class Product < ApplicationRecord
    has_many :variants, :dependent => :delete_all
    belongs_to :type

    class Type < ActiveRecord::Base
      has_many :products
    end
  end

  class Variant < ApplicationRecord
  end
end
