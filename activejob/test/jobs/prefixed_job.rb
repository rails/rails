# frozen_string_literal: true

class PrefixedJob < ActiveJob::Base
  self.queue_name_prefix = "production"

  def perform; end
end
