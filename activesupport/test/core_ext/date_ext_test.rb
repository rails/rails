require File.dirname(__FILE__) + '/../abstract_unit'

class DateExtCalculationsTest < Test::Unit::TestCase
  def test_to_s
    date = Date.new(2005, 2, 21)
    assert_equal "2005-02-21",          date.to_s
    assert_equal "21 Feb",              date.to_s(:short)
    assert_equal "February 21, 2005",   date.to_s(:long)
    assert_equal "February 21st, 2005", date.to_s(:long_ordinal)
    assert_equal "2005-02-21",          date.to_s(:db)
    assert_equal "21 Feb 2005",         date.to_s(:rfc822)
  end

  def test_readable_inspect
    assert_equal "Mon, 21 Feb 2005", Date.new(2005, 2, 21).readable_inspect
    assert_equal Date.new(2005, 2, 21).readable_inspect, Date.new(2005, 2, 21).inspect
  end

  def test_to_time
    assert_equal Time.local(2005, 2, 21), Date.new(2005, 2, 21).to_time
    assert_equal Time.local_time(2039, 2, 21), Date.new(2039, 2, 21).to_time
  end

  def test_to_datetime
    assert_equal DateTime.civil(2005, 2, 21), Date.new(2005, 2, 21).to_datetime
    assert_equal 0, Date.new(2005, 2, 21).to_datetime.offset # use UTC offset
    assert_equal ::Date::ITALY, Date.new(2005, 2, 21).to_datetime.start # use Ruby's default start value
  end

  def test_to_date
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 21).to_date
  end

  def test_change
    assert_equal Date.new(2005, 2, 21), Date.new(2005, 2, 11).change(:day => 21)
    assert_equal Date.new(2007, 5, 11), Date.new(2005, 2, 11).change(:year => 2007, :month => 5)
    assert_equal Date.new(2006,2,22), Date.new(2005,2,22).change(:year => 2006)
    assert_equal Date.new(2005,6,22), Date.new(2005,2,22).change(:month => 6)
  end

  def test_beginning_of_week
    assert_equal Date.new(2005,1,31),  Date.new(2005,2,4).beginning_of_week
    assert_equal Date.new(2005,11,28), Date.new(2005,11,28).beginning_of_week #monday
    assert_equal Date.new(2005,11,28), Date.new(2005,11,29).beginning_of_week #tuesday
    assert_equal Date.new(2005,11,28), Date.new(2005,11,30).beginning_of_week #wednesday
    assert_equal Date.new(2005,11,28), Date.new(2005,12,01).beginning_of_week #thursday
    assert_equal Date.new(2005,11,28), Date.new(2005,12,02).beginning_of_week #friday
    assert_equal Date.new(2005,11,28), Date.new(2005,12,03).beginning_of_week #saturday
    assert_equal Date.new(2005,11,28), Date.new(2005,12,04).beginning_of_week #sunday
  end

  def test_beginning_of_month
    assert_equal Date.new(2005,2,1), Date.new(2005,2,22).beginning_of_month
  end

  def test_beginning_of_quarter
    assert_equal Date.new(2005,1,1),  Date.new(2005,2,15).beginning_of_quarter
    assert_equal Date.new(2005,1,1),  Date.new(2005,1,1).beginning_of_quarter
    assert_equal Date.new(2005,10,1), Date.new(2005,12,31).beginning_of_quarter
    assert_equal Date.new(2005,4,1),  Date.new(2005,6,30).beginning_of_quarter
  end

  def test_end_of_month
    assert_equal Date.new(2005,3,31), Date.new(2005,3,20).end_of_month
    assert_equal Date.new(2005,2,28), Date.new(2005,2,20).end_of_month
    assert_equal Date.new(2005,4,30), Date.new(2005,4,20).end_of_month

  end

  def test_beginning_of_year
    assert_equal Date.new(2005,1,1).to_s, Date.new(2005,2,22).beginning_of_year.to_s
  end

  def test_months_ago
    assert_equal Date.new(2005,5,5),  Date.new(2005,6,5).months_ago(1)
    assert_equal Date.new(2004,11,5), Date.new(2005,6,5).months_ago(7)
    assert_equal Date.new(2004,12,5), Date.new(2005,6,5).months_ago(6)
    assert_equal Date.new(2004,6,5),  Date.new(2005,6,5).months_ago(12)
    assert_equal Date.new(2003,6,5),  Date.new(2005,6,5).months_ago(24)
  end

  def test_months_since
    assert_equal Date.new(2005,7,5),  Date.new(2005,6,5).months_since(1)
    assert_equal Date.new(2006,1,5),  Date.new(2005,12,5).months_since(1)
    assert_equal Date.new(2005,12,5), Date.new(2005,6,5).months_since(6)
    assert_equal Date.new(2006,6,5),  Date.new(2005,12,5).months_since(6)
    assert_equal Date.new(2006,1,5),  Date.new(2005,6,5).months_since(7)
    assert_equal Date.new(2006,6,5),  Date.new(2005,6,5).months_since(12)
    assert_equal Date.new(2007,6,5),  Date.new(2005,6,5).months_since(24)
    assert_equal Date.new(2005,4,30),  Date.new(2005,3,31).months_since(1)
    assert_equal Date.new(2005,2,28),  Date.new(2005,1,29).months_since(1)
    assert_equal Date.new(2005,2,28),  Date.new(2005,1,30).months_since(1)
    assert_equal Date.new(2005,2,28),  Date.new(2005,1,31).months_since(1)
  end

  def test_years_ago
    assert_equal Date.new(2004,6,5),  Date.new(2005,6,5).years_ago(1)
    assert_equal Date.new(1998,6,5), Date.new(2005,6,5).years_ago(7)
    assert_equal Date.new(2003,2,28), Date.new(2004,2,29).years_ago(1) # 1 year ago from leap day
  end

  def test_years_since
    assert_equal Date.new(2006,6,5),  Date.new(2005,6,5).years_since(1)
    assert_equal Date.new(2012,6,5),  Date.new(2005,6,5).years_since(7)
    assert_equal Date.new(2182,6,5),  Date.new(2005,6,5).years_since(177)
    assert_equal Date.new(2005,2,28), Date.new(2004,2,29).years_since(1) # 1 year since leap day
  end

  def test_last_year
    assert_equal Date.new(2004,6,5),  Date.new(2005,6,5).last_year
  end

  def test_next_year
    assert_equal Date.new(2006,6,5), Date.new(2005,6,5).next_year
  end

  def test_yesterday
    assert_equal Date.new(2005,2,21), Date.new(2005,2,22).yesterday
    assert_equal Date.new(2005,2,28), Date.new(2005,3,2).yesterday.yesterday
  end

  def test_tomorrow
    assert_equal Date.new(2005,2,23), Date.new(2005,2,22).tomorrow
    assert_equal Date.new(2005,3,2),  Date.new(2005,2,28).tomorrow.tomorrow
  end

  def test_advance
    assert_equal Date.new(2006,2,28), Date.new(2005,2,28).advance(:years => 1)
    assert_equal Date.new(2005,6,28), Date.new(2005,2,28).advance(:months => 4)
    assert_equal Date.new(2005,3,21), Date.new(2005,2,28).advance(:weeks => 3)
    assert_equal Date.new(2005,3,5), Date.new(2005,2,28).advance(:days => 5)
    assert_equal Date.new(2012,9,28), Date.new(2005,2,28).advance(:years => 7, :months => 7)
    assert_equal Date.new(2013,10,3), Date.new(2005,2,28).advance(:years => 7, :months => 19, :days => 5)
    assert_equal Date.new(2013,10,17), Date.new(2005,2,28).advance(:years => 7, :months => 19, :weeks => 2, :days => 5)
    assert_equal Date.new(2005,2,28), Date.new(2004,2,29).advance(:years => 1) #leap day plus one year
  end

  def test_next_week
    assert_equal Date.new(2005,2,28), Date.new(2005,2,22).next_week
    assert_equal Date.new(2005,3,4), Date.new(2005,2,22).next_week(:friday)
    assert_equal Date.new(2006,10,30), Date.new(2006,10,23).next_week
    assert_equal Date.new(2006,11,1), Date.new(2006,10,23).next_week(:wednesday)
  end

  def test_next_month_on_31st
    assert_equal Date.new(2005, 9, 30), Date.new(2005, 8, 31).next_month
  end

  def test_last_month_on_31st
    assert_equal Date.new(2004, 2, 29), Date.new(2004, 3, 31).last_month
  end  

  def test_yesterday_constructor
    assert_equal Date.today - 1, Date.yesterday
  end

  def test_tomorrow_constructor
    assert_equal Date.today + 1, Date.tomorrow
  end

  def test_since
    assert_equal Time.local(2005,2,21,0,0,45), Date.new(2005,2,21).since(45)
  end

  def test_ago
    assert_equal Time.local(2005,2,20,23,59,15), Date.new(2005,2,21).ago(45)
  end

  def test_beginning_of_day
    assert_equal Time.local(2005,2,21,0,0,0), Date.new(2005,2,21).beginning_of_day
  end

  def test_end_of_day
    assert_equal Time.local(2005,2,21,23,59,59), Date.new(2005,2,21).end_of_day
  end
  
  def test_xmlschema
    with_timezone 'US/Eastern' do
      assert_match(/^1980-02-28T00:00:00-05:?00$/, Date.new(1980, 2, 28).xmlschema)
      assert_match(/^1980-06-28T00:00:00-04:?00$/, Date.new(1980, 6, 28).xmlschema)
      # these tests are only of interest on platforms where older dates #to_time fail over to DateTime
      if ::DateTime === Date.new(1880, 6, 28).to_time
        assert_match(/^1880-02-28T00:00:00-05:?00$/, Date.new(1880, 2, 28).xmlschema)
        assert_match(/^1880-06-28T00:00:00-05:?00$/, Date.new(1880, 6, 28).xmlschema) # DateTimes aren't aware of DST rules
      end
    end
  end

  protected
    def with_timezone(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end  
end
