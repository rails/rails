class Admin::User < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ]
end
