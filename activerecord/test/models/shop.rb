module Shop
  class Collection < ActiveRecord::Base
    has_many :products, dependent: :nullify
  end

  class Product < ActiveRecord::Base
    has_many :variants, dependent: :delete_all
    belongs_to :type

    class Type < ActiveRecord::Base
      has_many :products
    end
  end

  class Variant < ActiveRecord::Base
  end
end
