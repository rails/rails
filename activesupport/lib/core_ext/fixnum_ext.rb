class Fixnum
  def minutes
    self * 60
  end
  alias :minute :minutes  
  
  def hours
    self * 60.minutes
  end
  alias :hour :hours
  
  def days
    self * 24.hours
  end
  alias :day :days

  def weeks
    self * 7.days
  end
  alias :week :weeks
  
  def fortnights
    self * 2.weeks
  end
  alias :fortnight :fortnights
  
  def months
    self * 30.days
  end
  alias :month :months
  
  def years
    self * 365.days
  end
  alias :year :years
end