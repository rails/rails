class UserBusiness < ActiveRecord::Base
  belongs_to :user
  belongs_to :business, primary_key: :uuid
end
