# frozen_string_literal: true

class DummyConfig # :nodoc:
  def initialize(config)
    @config = config
  end

  def to_s
    "DummyConfig"
  end

  def method_missing(selector, ...)
    if @config.respond_to?(selector)
      @config.send(selector, ...)
    else
      self
    end
  end
end
