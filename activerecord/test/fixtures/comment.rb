class Comment < ActiveRecord::Base
  belongs_to :post
end

class SpecialComment < Comment; end;