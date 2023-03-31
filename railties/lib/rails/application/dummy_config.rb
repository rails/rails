# frozen_string_literal: true

class DummyConfig # :nodoc:
  def initialize(config)
    @config = config
  end

  def to_s
    "DummyConfig"
  end

  def method_missing(selector, *args, &blk)
    if @config.respond_to?(selector)
      @config.send(selector, *args, &blk)
    else
      self
    end
  end
end
