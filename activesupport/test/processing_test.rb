# frozen_string_literal: true

require_relative "abstract_unit"

class ProcessingTest < ActiveSupport::TestCase
  class HTMLElement
    attr_reader :tag

    def initialize(tag:)
      @tag = tag
    end
  end

  class HTMLButtonElement < HTMLElement
    def initialize
      super(tag: :button)
    end
  end

  class HTMLFormElement < HTMLElement
    def initialize
      super(tag: :form)
    end
  end

  class HTMLLinkElement < HTMLElement
    def initialize
      super(tag: :link)
    end
  end

  class HTMLProcessor
    include ActiveSupport::Processing

    # Implement `#identify` to identify HTML elements, and dispatch them to
    # right handlers
    def identify(element)
      element.tag
    end

    # Invoked if `element.tag == :button`
    def on_button(element)
      element.class
    end

    # Invoked if `element.tag == :form`
    def on_form(element)
      element.class
    end
  end

  def test_should_process_elements_with_handlers
    elements  = [
      HTMLButtonElement.new,
      HTMLFormElement.new,
      HTMLLinkElement.new
    ]

    assert_equal [HTMLButtonElement, HTMLFormElement], HTMLProcessor.process(elements)
  end
end
