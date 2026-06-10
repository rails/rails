# frozen_string_literal: true

class ActiveStorage::BaseJob < ActiveJob::Base
end

ActiveSupport.run_load_hooks :active_storage_base_job, ActiveStorage::BaseJob
