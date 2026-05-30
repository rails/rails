# frozen_string_literal: true

class Default < ActiveRecord::Base
  attr_accessor :after_update_commit_called

  after_update_commit do |record|
    record.after_update_commit_called = true
  end
end
