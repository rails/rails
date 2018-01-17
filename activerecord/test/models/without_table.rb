# frozen_string_literal: true

class WithoutTable < ActiveRecord::Base
  default_scope -> { where(published: true) }
end
