**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Concerns
========

So what exactly is a concern, and what do you do with the concerns folders in /controllers and /models ?

After reading this guide, you will know:

* What a concern is
* What the /concerns folders are meant to contain
* How to write a concern
* How to use a concern in your controllers and models

---------------------------------------------------------------

Why Use Concerns?
----------------------

A concern is essentially a module that contains functions you would like to be able to use for multiple controllers or actions. They are a good way to keep your controllers and models small and keep your code DRY.

For example, imagine we are working on a website for a teacher at a college. They have given students the option to book appointments in advance should they want help. The teacher wants to keep track of the appointments they make with their students. Part of that means checking that the start and end of the timerange a student enters make sense.

We could write a custom validation that makes sure that the beginning and end of a time range are in the correct order (EG the start time is before the end time)


```ruby
class Appointment < ActiveRecord::Base

 validates :student_name, presence: true

 validates :issue, presence: true


 validates :time_range, presence: true

 validate: :validates_time_range

 def validates_time_range
   unless Appointment.start_before_end?(time_range)
     errors.add(:time_range, "This is an invalid time range. It cannot end before it starts!")
   end
 end


 private

   def start_before_end?(time_range_var)
     if time_range_var.nil?
      return false
    end

    unless time_range_var.begin < time_range_var.end
      false
    else
      true
    end
  end

end
```

Now, this will work wonderfully. But what if the teacher also wants our website to keep track of office hours? Office hours also have a start and end.

```ruby
class OfficeHour < ActiveRecord::Base

 validates :location, presence: true

 validates :time_range, presence: true

 validate: :validates_time_range

 def validates_time_range
   unless OfficeHour.start_before_end?(time_range)
     errors.add(:time_range, "This is an invalid time range. It cannot end before it starts!")
   end
 end


 private

   def start_before_end?(time_range_var)
     if time_range_var.nil?
      return false
    end

    unless time_range_var.begin < time_range_var.end
      false
    else
      true
    end
  end

end
```

As you can see, while Appointment and OfficeHour both have a lot in common, they are not exactly the same. In fact, they both use a lot of the same code - the validation on time_range for both models is exactly the same. Wouldn't it be cleaner if we could keep the code for that validation function elsewhere and use it in both places at once? Well, we can do just that with concerns.

Writing a Concern
-----------------

If you have ever wondered exactly what is supposed to go into the concerns folders of your Rails app, you are about to find out.

If we use the previous example of wanting to place code common to more than one model into a concern, we will put the concern file in /app/models/concerns . For code shared between controllers you can use the app/controllers/concerns folder.

Our example was a function, `start_before_end`, which checks a time range to make sure the end of the time range is after the time range's start. We will create a Ruby file called `time_range_validators.rb` within which we will store our function. The file will contain a module with the same name in camel case (`TimeRangeValidators`). This is just a matter of convention - you can name the module whatever you like.
In Rails, concern modules must also extend ActiveSupport::Concern.

Inside our new module we can store the `start_before_end` function:

```
 module TimeRangeValidators
   extend ActiveSupport::Concern

   def start_before_end?(time_range_var)
     if time_range_var.nil?
      return false
    end

    unless time_range_var.begin < time_range_var.end
      false
    else
      true
    end
  end

 end
```

The module name TimeRangeValidators allows us to store other functions in this module should we need to down the road. A more specific name would make the functionality of the module too limited.



