# frozen_string_literal: true

class ProcMailer < ActionMailer::Base
  default to: "system@test.lindsaar.net",
          "X-Proc-Method" => Proc.new { Time.now.to_i.to_s },
          subject: Proc.new { give_a_greeting },
          "x-has-to-proc" => :symbol,
          "X-Lambda-Arity-0" => ->() { "0" },
          "X-Lambda-Arity-1-arg" => ->(arg) { arg.computed_value },
          "X-Lambda-Arity-1-self" => ->(_) { self.computed_value }

  def welcome
    mail
  end

  def computed_value
    "complex_value"
  end

  private

    def give_a_greeting
      "Thanks for signing up this afternoon"
    end
end
