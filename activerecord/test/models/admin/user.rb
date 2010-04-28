class Admin::User < ActiveRecord::Base
  belongs_to :account
end