# frozen_string_literal: true

module LeakChecker
  # These keys are out of our control.
  # Either added by the system or by other libraries.
  ALLOWED_KEYS = %w[
    VIPSHOME
  ]

  def before_setup
    @__leak_checker_before_env = ENV.to_h
    super
  end

  def after_teardown
    super

    after = ENV.to_h
    before = @__leak_checker_before_env

    ALLOWED_KEYS.each do |k|
      after.delete(k)
      before.delete(k)
    end

    if after != before
      message = +"Environment leak detected:\n"
      added_keys = after.keys - before.keys
      unless added_keys.empty?
        message << "  - Added variables:\n"
        added_keys.each do |k|
          message << "    - #{k}"
        end
      end

      removed_keys = before.keys - after.keys
      unless removed_keys.empty?
        message << "  - Removed variables:\n"
        removed_keys.each do |k|
          message << "    - #{k}"
        end
      end

      changed_keys = (before.keys & after.keys).select { |k| before[k] != after[k] }
      unless changed_keys.empty?
        message << "  - Changed variables:\n"
        changed_keys.each do |k|
          message << "    - #{k} from #{before[k].inspect} to #{after[k].inspect}"
        end
      end

      flunk message
    end
  end
end
