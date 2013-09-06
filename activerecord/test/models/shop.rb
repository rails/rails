module Shop
  class Collection < ApplicationModel
    has_many :products, :dependent => :nullify
  end

  class Product < ApplicationModel
    has_many :variants, :dependent => :delete_all
  end

  class Variant < ApplicationModel
  end
end
