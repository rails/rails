# frozen_string_literal: true

class BinaryField < ActiveRecord::Base
  serialize :normal_blob
  serialize :normal_text
end
