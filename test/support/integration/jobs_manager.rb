class JobsManager
  @@managers = {}
  attr :adapter_name

  def self.current_manager
    @@managers[ENV['AJADAPTER']] ||= new(ENV['AJADAPTER'])
  end

  def initialize(adapter_name)
    @adapter_name = adapter_name
    require_relative "adapters/#{adapter_name}"
    extend "#{adapter_name.camelize}JobsManager".constantize
  end

  def setup
  end

  def start_workers
  end

  def stop_workers
  end
end
