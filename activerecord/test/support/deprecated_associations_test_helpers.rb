# frozen_string_literal: true

module DeprecatedAssociationsTestHelpers
  private
    def assert_deprecated_association(association, model: @model, context:, &)
      expected_context = context
      reported = false
      mock = ->(reflection, context:) do
        if reflection.name == association && reflection.active_record == model && expected_context == context
          reported = true
        end
      end
      ActiveRecord::Associations::Deprecation.stub(:report, mock, &)
      assert reported, "Expected a notification for #{model}##{association}, but got none"
    end

    def assert_not_deprecated_association(association, model: @model, &)
      reported = false
      mock = ->(reflection, context:) do
        return if reflection.name != association
        return if reflection.active_record != model
        reported = true
      end
      ActiveRecord::Associations::Deprecation.stub(:report, mock, &)
      assert_not reported, "Got a notification for #{model}##{association}, but expected none"
    end

    def context_for_method(method_name)
      "the method #{method_name} was invoked"
    end

    def context_for_dependent
      ":dependent has a side effect here"
    end

    def context_for_touch
      ":touch has a side effect here"
    end

    def context_for_through(association, model: @model)
      "referenced as nested association of the through #{model}##{association}"
    end

    def context_for_preload
      "referenced in query to preload records"
    end

    def context_for_join
      "referenced in query to join its table"
    end
end
