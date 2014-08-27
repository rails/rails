require File.expand_path('../../../load_paths', __FILE__)

require 'active_job'

GlobalID.app = 'aj'

@adapter  = ENV['AJADAPTER'] || 'inline'

def sidekiq?
  @adapter == 'sidekiq'
end

def ruby_193?
  RUBY_VERSION == '1.9.3' && RUBY_ENGINE != 'java'
end

# Sidekiq doesn't work with MRI 1.9.3
exit if sidekiq? && ruby_193?

require "adapters/#{@adapter}"

require 'active_support/testing/autorun'

ActiveJob::Base.logger.level = Logger::DEBUG
