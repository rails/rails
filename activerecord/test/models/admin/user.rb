class Admin::User < ActiveRecord::Base
  belongs_to :account
  store :settings, :accessors => [ :color, :homepage ]
  store :preferences, :accessors => [ :remember_login ]
  store :novel, :accessors => [ :title ], :namespace => :book
  store :magazine, :accessors => [ :cover ], :namespace => true
end
