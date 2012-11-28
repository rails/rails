class Admin::User < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ]
  store_accessor :settings, :favorite_food
  store :preferences, :accessors => [ :remember_login ]
  store :json_data, :accessors => [ :height, :weight ], :coder => JSON
  store :json_data_empty, :accessors => [ :is_a_good_guy ], :coder => JSON

  def phone_number
    read_store_attribute(:settings, :phone_number).gsub(/(\d{3})(\d{3})(\d{4})/,'(\1) \2-\3')
  end

  def phone_number=(value)
    write_store_attribute(:settings, :phone_number, value && value.gsub(/[^\d]/,''))
  end
end
