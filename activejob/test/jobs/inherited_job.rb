# frozen_string_literal: true

require_relative 'application_job'

class InheritedJob < ApplicationJob
  self.queue_adapter = :inline
end
