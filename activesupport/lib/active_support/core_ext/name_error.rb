# frozen_string_literal: true

class NameError
  # Extract the name of the missing constant from the exception message.
  #
  #   begin
  #     HelloWorld
  #   rescue NameError => e
  #     e.missing_name
  #   end
  #   # => "HelloWorld"
  def missing_name
    # Since ruby v2.3.0 `did_you_mean` gem is loaded by default.
    # It extends NameError#message with spell corrections which are SLOW.
    # We should use original_message message instead.
    message = respond_to?(:original_message) ? original_message : self.message

    if /undefined local variable or method/ !~ message
      $1 if /((::)?([A-Z]\w*)(::[A-Z]\w*)*)$/ =~ message
    end
  end

  # Was this exception raised because the given name was missing?
  #
  #   begin
  #     HelloWorld
  #   rescue NameError => e
  #     e.missing_name?("HelloWorld")
  #   end
  #   # => true
  def missing_name?(name)
    if name.is_a? Symbol
      self.name == name
    else
      missing_name == name.to_s
    end
  end
end
