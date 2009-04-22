require 'date'

class Time
  # Ruby 1.8-cvs and early 1.9 series define private Time#to_date
  %w(to_date to_datetime).each do |method|
    if private_instance_methods.include?(method) || private_instance_methods.include?(method.to_sym)
      public method
    end
  end
end
