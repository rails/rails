module Shop
  class Collection < ApplicationModel
    has_many :products, :dependent => :nullify
  end

  class Product < ApplicationModel
    has_many :variants, :dependent => :delete_all
    belongs_to :type

    class Type < ActiveRecord::Base
      has_many :products
    end
  end

  class Variant < ApplicationModel
  end
end
