require File.expand_path('../../../load_paths', __FILE__)

require 'active_job'

@adapter  = ENV['AJADAPTER'] || 'inline'

def sidekiq?
  @adapter == 'sidekiq'
end

def rubinius?
  RUBY_ENGINE == 'rbx'
end

def ruby_193?
  RUBY_VERSION == '1.9.3' && RUBY_ENGINE != 'java'
end

#Sidekiq don't work with MRI 1.9.3
#Travis uses rbx 2.6 which don't support unicode characters in methods.
#Remove the check when Travis change to rbx 2.7+
exit  if sidekiq?  && (ruby_193? || rubinius?)

require "adapters/#{@adapter}"

require 'active_support/testing/autorun'

ActiveJob::Base.logger.level = Logger::DEBUG
