class Admin::StructUser < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ], :type => OpenStruct
end
