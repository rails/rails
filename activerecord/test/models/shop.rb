module Shop
  class Collection < ApplicationRecord
    has_many :products, :dependent => :nullify
  end

  class Product < ApplicationRecord
    has_many :variants, :dependent => :delete_all
  end

  class Variant < ApplicationRecord
  end
end
