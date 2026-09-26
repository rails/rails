# frozen_string_literal: true

module ActiveStorage
  class RotationConfiguration # :nodoc:
    attr_reader :rotations

    delegate :each, to: :rotations

    def initialize
      @rotations = []
    end

    def rotate(*args, **options)
      args << options unless options.empty?
      @rotations << args
    end
  end
end
