class Admin::UserWithOrderedOptionsStore < Admin::User
  store :settings, :accessors => [ :color, :homepage ], :type => ActiveSupport::OrderedOptions
end
