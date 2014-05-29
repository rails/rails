require 'active_job/arguments'

module ActiveJob
  module Identifier
    extend ActiveSupport::Concern

    included do
      attr_writer :job_id
    end

    def job_id
      @job_id ||= SecureRandom.uuid
    end
  end
end
