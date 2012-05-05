class Admin::User < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ]
  store :preferences, :accessors => [ :remember_login ]
  store :novels, :accessors => [ :title ], :prefix => :book
  store :magazines, :accessors => [ :cover ], :prefix => true
end
