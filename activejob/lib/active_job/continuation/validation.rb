# frozen_string_literal: true

module ActiveJob
  class Continuation
    module Validation # :nodoc:
      private
        def validate_step!(name)
          validate_step_symbol!(name)
          validate_step_not_encountered!(name)
          validate_step_not_nested!(name)
          validate_step_resume_expected!(name)
          validate_step_expected_order!(name)
        end

        def validate_step_symbol!(name)
          unless name.is_a?(Symbol)
            raise_step_error! "Step '#{name}' must be a Symbol, found '#{name.class}'"
          end
        end

        def validate_step_not_encountered!(name)
          if encountered.include?(name)
            raise_step_error! "Step '#{name}' has already been encountered"
          end
        end

        def validate_step_not_nested!(name)
          if running_step?
            raise_step_error! "Step '#{name}' is nested inside step '#{current.name}'"
          end
        end

        def validate_step_resume_expected!(name)
          if current && current.name != name && !completed?(name)
            raise_step_error! "Step '#{name}' found, expected to resume from '#{current.name}'"
          end
        end

        def validate_step_expected_order!(name)
          if completed.size > encountered.size && completed[encountered.size] != name
            raise_step_error! "Step '#{name}' found, expected to see '#{completed[encountered.size]}'"
          end
        end

        def raise_step_error!(message)
          raise InvalidStepError, message
        end
    end
  end
end
