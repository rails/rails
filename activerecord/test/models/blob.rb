# frozen_string_literal: true

class Blob < ActiveRecord::Base
  serialize :blob
end
