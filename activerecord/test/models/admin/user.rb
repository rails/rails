class Admin::User < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ]
  store :preferences, :accessors => [ :remember_login ]
  store :json_data, :accessors => [ :height, :weight ], :coder => JSON
  store :json_data_empty, :accessors => [ :is_a_good_guy ], :coder => JSON
end
