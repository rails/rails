require 'date'

class Time
  # Ruby 1.8-cvs and early 1.9 series define private Time#to_date
  %w(to_date to_datetime).each do |method|
    if (m = instance_method(method) rescue nil) && private_instance_methods.include?(m.name)
      public method
    end
  end
end
