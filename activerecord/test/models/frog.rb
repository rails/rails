# frozen_string_literal: true

class Frog < ActiveRecord::Base
  after_save do
    with_lock do
    end
  end
end
