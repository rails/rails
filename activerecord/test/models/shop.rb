module Shop
  class Collection < ActiveRecord::Base
    has_many :products, :dependent => :nullify
  end

  class Product < ActiveRecord::Base
    has_many :variants, :dependent => :delete_all
  end

  class Variant < ActiveRecord::Base
  end
end
