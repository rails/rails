require "#{File.dirname(__FILE__)}/../abstract_unit"

class DateHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::FormHelper

  silence_warnings do
    Post = Struct.new("Post", :id, :written_on, :updated_at)
    Post.class_eval do
      def id
        123
      end
      def id_before_type_cast
        123
      end
    end
  end

  def test_distance_in_words
    from = Time.mktime(2004, 6, 6, 21, 45, 0)

    # 0..1 with include_seconds
    assert_equal "less than 5 seconds", distance_of_time_in_words(from, from + 0.seconds, true)
    assert_equal "less than 5 seconds", distance_of_time_in_words(from, from + 4.seconds, true)
    assert_equal "less than 10 seconds", distance_of_time_in_words(from, from + 5.seconds, true)
    assert_equal "less than 10 seconds", distance_of_time_in_words(from, from + 9.seconds, true)
    assert_equal "less than 20 seconds", distance_of_time_in_words(from, from + 10.seconds, true)
    assert_equal "less than 20 seconds", distance_of_time_in_words(from, from + 19.seconds, true)
    assert_equal "half a minute", distance_of_time_in_words(from, from + 20.seconds, true)
    assert_equal "half a minute", distance_of_time_in_words(from, from + 39.seconds, true)
    assert_equal "less than a minute", distance_of_time_in_words(from, from + 40.seconds, true)
    assert_equal "less than a minute", distance_of_time_in_words(from, from + 59.seconds, true)
    assert_equal "1 minute", distance_of_time_in_words(from, from + 60.seconds, true)
    assert_equal "1 minute", distance_of_time_in_words(from, from + 89.seconds, true)

    # First case 0..1
    assert_equal "less than a minute", distance_of_time_in_words(from, from + 0.seconds)
    assert_equal "less than a minute", distance_of_time_in_words(from, from + 29.seconds)
    assert_equal "1 minute", distance_of_time_in_words(from, from + 30.seconds)
    assert_equal "1 minute", distance_of_time_in_words(from, from + 1.minutes + 29.seconds)

    # 2..44
    assert_equal "2 minutes", distance_of_time_in_words(from, from + 1.minutes + 30.seconds)
    assert_equal "44 minutes", distance_of_time_in_words(from, from + 44.minutes + 29.seconds)

    # 45..89
    assert_equal "about 1 hour", distance_of_time_in_words(from, from + 44.minutes + 30.seconds)
    assert_equal "about 1 hour", distance_of_time_in_words(from, from + 89.minutes + 29.seconds)

    # 90..1439
    assert_equal "about 2 hours", distance_of_time_in_words(from, from + 89.minutes + 30.seconds)
    assert_equal "about 24 hours", distance_of_time_in_words(from, from + 23.hours + 59.minutes + 29.seconds)

    # 1440..2879
    assert_equal "1 day", distance_of_time_in_words(from, from + 23.hours + 59.minutes + 30.seconds)
    assert_equal "1 day", distance_of_time_in_words(from, from + 47.hours + 59.minutes + 29.seconds)

    # 2880..43199
    assert_equal "2 days", distance_of_time_in_words(from, from + 47.hours + 59.minutes + 30.seconds)
    assert_equal "29 days", distance_of_time_in_words(from, from + 29.days + 23.hours + 59.minutes + 29.seconds)

    # 43200..86399
    assert_equal "about 1 month", distance_of_time_in_words(from, from + 29.days + 23.hours + 59.minutes + 30.seconds)
    assert_equal "about 1 month", distance_of_time_in_words(from, from + 59.days + 23.hours + 59.minutes + 29.seconds)

    # 86400..525599
    assert_equal "2 months", distance_of_time_in_words(from, from + 59.days + 23.hours + 59.minutes + 30.seconds)
    assert_equal "12 months", distance_of_time_in_words(from, from + 1.years - 31.seconds)

    # 525600..1051199
    assert_equal "about 1 year", distance_of_time_in_words(from, from + 1.years - 30.seconds)
    assert_equal "about 1 year", distance_of_time_in_words(from, from + 2.years - 31.seconds)

    # > 1051199
    assert_equal "over 2 years", distance_of_time_in_words(from, from + 2.years + 30.seconds)
    assert_equal "over 10 years", distance_of_time_in_words(from, from + 10.years)

    # test to < from
    assert_equal "about 4 hours", distance_of_time_in_words(from + 4.hours, from)
    assert_equal "less than 20 seconds", distance_of_time_in_words(from + 19.seconds, from, true)

    # test with integers
    assert_equal "less than a minute", distance_of_time_in_words(59)
    assert_equal "about 1 hour", distance_of_time_in_words(60*60)
    assert_equal "less than a minute", distance_of_time_in_words(0, 59)
    assert_equal "about 1 hour", distance_of_time_in_words(60*60, 0)
  end

  def test_distance_in_words_with_dates
    start_date = Date.new 1975, 1, 31
    end_date = Date.new 1977, 1, 31
    assert_equal("over 2 years", distance_of_time_in_words(start_date, end_date))
  end

  def test_time_ago_in_words
    assert_equal "about 1 year", time_ago_in_words(1.year.ago - 1.day)
  end

  def test_select_day
    expected = %(<select id="date_day" name="date[day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_day(Time.mktime(2003, 8, 16))
    assert_equal expected, select_day(16)
  end

  def test_select_day_with_blank
    expected = %(<select id="date_day" name="date[day]">\n)
    expected << %(<option value=""></option>\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_day(Time.mktime(2003, 8, 16), :include_blank => true)
    assert_equal expected, select_day(16, :include_blank => true)
  end

  def test_select_day_nil_with_blank
    expected = %(<select id="date_day" name="date[day]">\n)
    expected << %(<option value=""></option>\n<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_day(nil, :include_blank => true)
  end

  def test_select_month
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16))
    assert_equal expected, select_month(8)
  end

  def test_select_month_with_disabled
    expected = %(<select id="date_month" name="date[month]" disabled="disabled">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :disabled => true)
    assert_equal expected, select_month(8, :disabled => true)
  end

  def test_select_month_with_field_name_override
    expected = %(<select id="date_mois" name="date[mois]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :field_name => 'mois')
    assert_equal expected, select_month(8, :field_name => 'mois')
  end

  def test_select_month_with_blank
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value=""></option>\n<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :include_blank => true)
    assert_equal expected, select_month(8, :include_blank => true)
  end

  def test_select_month_nil_with_blank
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value=""></option>\n<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(nil, :include_blank => true)
  end

  def test_select_month_with_numbers
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8" selected="selected">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :use_month_numbers => true)
    assert_equal expected, select_month(8, :use_month_numbers => true)
  end

  def test_select_month_with_numbers_and_names
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value="1">1 - January</option>\n<option value="2">2 - February</option>\n<option value="3">3 - March</option>\n<option value="4">4 - April</option>\n<option value="5">5 - May</option>\n<option value="6">6 - June</option>\n<option value="7">7 - July</option>\n<option value="8" selected="selected">8 - August</option>\n<option value="9">9 - September</option>\n<option value="10">10 - October</option>\n<option value="11">11 - November</option>\n<option value="12">12 - December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :add_month_numbers => true)
    assert_equal expected, select_month(8, :add_month_numbers => true)
  end

  def test_select_month_with_numbers_and_names_with_abbv
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value="1">1 - Jan</option>\n<option value="2">2 - Feb</option>\n<option value="3">3 - Mar</option>\n<option value="4">4 - Apr</option>\n<option value="5">5 - May</option>\n<option value="6">6 - Jun</option>\n<option value="7">7 - Jul</option>\n<option value="8" selected="selected">8 - Aug</option>\n<option value="9">9 - Sep</option>\n<option value="10">10 - Oct</option>\n<option value="11">11 - Nov</option>\n<option value="12">12 - Dec</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :add_month_numbers => true, :use_short_month => true)
    assert_equal expected, select_month(8, :add_month_numbers => true, :use_short_month => true)
  end

  def test_select_month_with_abbv
    expected = %(<select id="date_month" name="date[month]">\n)
    expected << %(<option value="1">Jan</option>\n<option value="2">Feb</option>\n<option value="3">Mar</option>\n<option value="4">Apr</option>\n<option value="5">May</option>\n<option value="6">Jun</option>\n<option value="7">Jul</option>\n<option value="8" selected="selected">Aug</option>\n<option value="9">Sep</option>\n<option value="10">Oct</option>\n<option value="11">Nov</option>\n<option value="12">Dec</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :use_short_month => true)
    assert_equal expected, select_month(8, :use_short_month => true)
  end

  def test_select_month_with_custom_names
    month_names = %w(nil Januar Februar Marts April Maj Juni Juli August September Oktober November December)

    expected = %(<select id="date_month" name="date[month]">\n)
    1.upto(12) { |month| expected << %(<option value="#{month}"#{' selected="selected"' if month == 8}>#{month_names[month]}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :use_month_names => month_names)
    assert_equal expected, select_month(8, :use_month_names => month_names)
  end

  def test_select_month_with_zero_indexed_custom_names
    month_names = %w(Januar Februar Marts April Maj Juni Juli August September Oktober November December)

    expected = %(<select id="date_month" name="date[month]">\n)
    1.upto(12) { |month| expected << %(<option value="#{month}"#{' selected="selected"' if month == 8}>#{month_names[month-1]}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :use_month_names => month_names)
    assert_equal expected, select_month(8, :use_month_names => month_names)
  end

  def test_select_month_with_hidden
    assert_dom_equal "<input type=\"hidden\" id=\"date_month\" name=\"date[month]\" value=\"8\" />\n", select_month(8, :use_hidden => true)
  end

  def test_select_month_with_hidden_and_field_name
    assert_dom_equal "<input type=\"hidden\" id=\"date_mois\" name=\"date[mois]\" value=\"8\" />\n", select_month(8, :use_hidden => true, :field_name => 'mois')
  end

  def test_select_year
    expected = %(<select id="date_year" name="date[year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_year(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005)
    assert_equal expected, select_year(2003, :start_year => 2003, :end_year => 2005)
  end

  def test_select_year_with_disabled
    expected = %(<select id="date_year" name="date[year]" disabled="disabled">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_year(Time.mktime(2003, 8, 16), :disabled => true, :start_year => 2003, :end_year => 2005)
    assert_equal expected, select_year(2003, :disabled => true, :start_year => 2003, :end_year => 2005)
  end

  def test_select_year_with_field_name_override
    expected = %(<select id="date_annee" name="date[annee]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_year(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :field_name => 'annee')
    assert_equal expected, select_year(2003, :start_year => 2003, :end_year => 2005, :field_name => 'annee')
  end

  def test_select_year_with_type_discarding
    expected = %(<select id="date_year" name="date_year">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_year(
      Time.mktime(2003, 8, 16), :prefix => "date_year", :discard_type => true, :start_year => 2003, :end_year => 2005)
    assert_equal expected, select_year(
      2003, :prefix => "date_year", :discard_type => true, :start_year => 2003, :end_year => 2005)
  end

  def test_select_year_descending
    expected = %(<select id="date_year" name="date[year]">\n)
    expected << %(<option value="2005" selected="selected">2005</option>\n<option value="2004">2004</option>\n<option value="2003">2003</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_year(Time.mktime(2005, 8, 16), :start_year => 2005, :end_year => 2003)
    assert_equal expected, select_year(2005, :start_year => 2005, :end_year => 2003)
  end

  def test_select_year_with_hidden
    assert_dom_equal "<input type=\"hidden\" id=\"date_year\" name=\"date[year]\" value=\"2007\" />\n", select_year(2007, :use_hidden => true)
  end

  def test_select_year_with_hidden_and_field_name
    assert_dom_equal "<input type=\"hidden\" id=\"date_anno\" name=\"date[anno]\" value=\"2007\" />\n", select_year(2007, :use_hidden => true, :field_name => 'anno')
  end

  def test_select_hour
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_hour(Time.mktime(2003, 8, 16, 8, 4, 18))
  end

  def test_select_hour_with_disabled
    expected = %(<select id="date_hour" name="date[hour]" disabled="disabled">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_hour(Time.mktime(2003, 8, 16, 8, 4, 18), :disabled => true)
  end

  def test_select_hour_with_field_name_override
    expected = %(<select id="date_heure" name="date[heure]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_hour(Time.mktime(2003, 8, 16, 8, 4, 18), :field_name => 'heure')
  end

  def test_select_hour_with_blank
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_hour(Time.mktime(2003, 8, 16, 8, 4, 18), :include_blank => true)
  end

  def test_select_hour_nil_with_blank
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_hour(nil, :include_blank => true)
  end

  def test_select_minute
    expected = %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18))
  end

  def test_select_minute_with_disabled
    expected = %(<select id="date_minute" name="date[minute]" disabled="disabled">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18), :disabled => true)
  end

  def test_select_minute_with_field_name_override
    expected = %(<select id="date_minuto" name="date[minuto]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18), :field_name => 'minuto')
  end

  def test_select_minute_with_blank
    expected = %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18), :include_blank => true)
  end

  def test_select_minute_with_blank_and_step
    expected = %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="15">15</option>\n<option value="30">30</option>\n<option value="45">45</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18), { :include_blank => true , :minute_step => 15 })
  end

  def test_select_minute_nil_with_blank
    expected = %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(nil, :include_blank => true)
  end

  def test_select_minute_nil_with_blank_and_step
    expected = %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="15">15</option>\n<option value="30">30</option>\n<option value="45">45</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(nil, { :include_blank => true , :minute_step => 15 })
  end

  def test_select_minute_with_hidden
    assert_dom_equal "<input type=\"hidden\" id=\"date_minute\" name=\"date[minute]\" value=\"8\" />\n", select_minute(8, :use_hidden => true)
  end

  def test_select_minute_with_hidden_and_field_name
    assert_dom_equal "<input type=\"hidden\" id=\"date_minuto\" name=\"date[minuto]\" value=\"8\" />\n", select_minute(8, :use_hidden => true, :field_name => 'minuto')
  end

  def test_select_second
    expected = %(<select id="date_second" name="date[second]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(Time.mktime(2003, 8, 16, 8, 4, 18))
  end

  def test_select_second_with_disabled
    expected = %(<select id="date_second" name="date[second]" disabled="disabled">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(Time.mktime(2003, 8, 16, 8, 4, 18), :disabled => true)
  end

  def test_select_second_with_field_name_override
    expected = %(<select id="date_segundo" name="date[segundo]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(Time.mktime(2003, 8, 16, 8, 4, 18), :field_name => 'segundo')
  end

  def test_select_second_with_blank
    expected = %(<select id="date_second" name="date[second]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(Time.mktime(2003, 8, 16, 8, 4, 18), :include_blank => true)
  end

  def test_select_second_nil_with_blank
    expected = %(<select id="date_second" name="date[second]">\n)
    expected << %(<option value=""></option>\n<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(nil, :include_blank => true)
  end

  def test_select_date
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :prefix => "date[first]")
  end

  def test_select_date_with_order
    expected = %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected <<  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :prefix => "date[first]", :order => [:month, :day, :year])
  end

  def test_select_date_with_incomplete_order
    expected = %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected <<  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :prefix => "date[first]", :order => [:day])
  end

  def test_select_date_with_disabled
    expected =  %(<select id="date_first_year" name="date[first][year]" disabled="disabled">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]" disabled="disabled">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]" disabled="disabled">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :prefix => "date[first]", :disabled => true)
  end

  def test_select_date_with_no_start_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+1) do |y|
      if y == Date.today.year
        expected << %(<option value="#{y}" selected="selected">#{y}</option>\n)
      else
        expected << %(<option value="#{y}">#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(
      Time.mktime(Date.today.year, 8, 16), :end_year => Date.today.year+1, :prefix => "date[first]"
    )
  end

  def test_select_date_with_no_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    2003.upto(2008) do |y|
      if y == 2003
        expected << %(<option value="#{y}" selected="selected">#{y}</option>\n)
      else
        expected << %(<option value="#{y}">#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(
      Time.mktime(2003, 8, 16), :start_year => 2003, :prefix => "date[first]"
    )
  end

  def test_select_date_with_no_start_or_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) do |y|
      if y == Date.today.year
        expected << %(<option value="#{y}" selected="selected">#{y}</option>\n)
      else
        expected << %(<option value="#{y}">#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(
      Time.mktime(Date.today.year, 8, 16), :prefix => "date[first]"
    )
  end

  def test_select_date_with_zero_value
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :start_year => 2003, :end_year => 2005, :prefix => "date[first]")
  end

  def test_select_date_with_zero_value_and_no_start_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+1) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :end_year => Date.today.year+1, :prefix => "date[first]")
  end

  def test_select_date_with_zero_value_and_no_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    last_year = Time.now.year + 5
    2003.upto(last_year) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :start_year => 2003, :prefix => "date[first]")
  end

  def test_select_date_with_zero_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :prefix => "date[first]")
  end

  def test_select_date_with_nil_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(nil, :prefix => "date[first]")
  end

  def test_select_datetime
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_hour" name="date[first][hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_minute" name="date[first][minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_datetime(Time.mktime(2003, 8, 16, 8, 4, 18), :start_year => 2003, :end_year => 2005, :prefix => "date[first]")
  end

  def test_select_datetime_with_separators
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    expected << %(<option value="2003" selected="selected">2003</option>\n<option value="2004">2004</option>\n<option value="2005">2005</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %(<select id="date_first_hour" name="date[first][hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << " : "

    expected << %(<select id="date_first_minute" name="date[first][minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_datetime(Time.mktime(2003, 8, 16, 8, 4, 18), :start_year => 2003, :end_year => 2005, :prefix => "date[first]", :datetime_separator => ' &mdash; ', :time_separator => ' : ')
  end

  def test_select_datetime_with_nil_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_hour" name="date[first][hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_minute" name="date[first][minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_datetime(nil, :prefix => "date[first]")
  end

  def test_select_time
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18))
    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :include_seconds => false)
  end

  def test_select_time_with_separator
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << " : "

    expected << %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :time_separator => ' : ')
    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :time_separator => ' : ', :include_seconds => false)
  end

  def test_select_time_with_seconds
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_second" name="date[second]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :include_seconds => true)
  end

  def test_select_time_with_seconds_and_separator
    expected = %(<select id="date_hour" name="date[hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08" selected="selected">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << " : "

    expected << %(<select id="date_minute" name="date[minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04" selected="selected">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    expected << " : "

    expected << %(<select id="date_second" name="date[second]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18" selected="selected">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :include_seconds => true, :time_separator => ' : ')
  end

  def test_date_select
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)

    expected = %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_written_on_3i" name="post[written_on(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}

    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on")
  end

  def test_date_select_without_day
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)

    expected = "<input type=\"hidden\" id=\"post_written_on_3i\" name=\"post[written_on(3i)]\" value=\"1\" />\n"

    expected <<  %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on", :order => [ :month, :year ])
  end

  def test_date_select_within_fields_for
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)

    _erbout = ''

    fields_for :post, @post do |f|
      _erbout.concat f.date_select(:written_on)
    end

    expected = "<select id='post_written_on_1i' name='post[written_on(1i)]'>\n<option value='1999'>1999</option>\n<option value='2000'>2000</option>\n<option value='2001'>2001</option>\n<option value='2002'>2002</option>\n<option value='2003'>2003</option>\n<option selected='selected' value='2004'>2004</option>\n<option value='2005'>2005</option>\n<option value='2006'>2006</option>\n<option value='2007'>2007</option>\n<option value='2008'>2008</option>\n<option value='2009'>2009</option>\n</select>\n"
    expected << "<select id='post_written_on_2i' name='post[written_on(2i)]'>\n<option value='1'>January</option>\n<option value='2'>February</option>\n<option value='3'>March</option>\n<option value='4'>April</option>\n<option value='5'>May</option>\n<option selected='selected' value='6'>June</option>\n<option value='7'>July</option>\n<option value='8'>August</option>\n<option value='9'>September</option>\n<option value='10'>October</option>\n<option value='11'>November</option>\n<option value='12'>December</option>\n</select>\n"
    expected << "<select id='post_written_on_3i' name='post[written_on(3i)]'>\n<option value='1'>1</option>\n<option value='2'>2</option>\n<option value='3'>3</option>\n<option value='4'>4</option>\n<option value='5'>5</option>\n<option value='6'>6</option>\n<option value='7'>7</option>\n<option value='8'>8</option>\n<option value='9'>9</option>\n<option value='10'>10</option>\n<option value='11'>11</option>\n<option value='12'>12</option>\n<option value='13'>13</option>\n<option value='14'>14</option>\n<option selected='selected' value='15'>15</option>\n<option value='16'>16</option>\n<option value='17'>17</option>\n<option value='18'>18</option>\n<option value='19'>19</option>\n<option value='20'>20</option>\n<option value='21'>21</option>\n<option value='22'>22</option>\n<option value='23'>23</option>\n<option value='24'>24</option>\n<option value='25'>25</option>\n<option value='26'>26</option>\n<option value='27'>27</option>\n<option value='28'>28</option>\n<option value='29'>29</option>\n<option value='30'>30</option>\n<option value='31'>31</option>\n</select>\n"

    assert_dom_equal(expected, _erbout)
  end

  def test_date_select_with_index
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)
    id = 456

    expected = %{<select id="post_456_written_on_1i" name="post[#{id}][written_on(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_456_written_on_2i" name="post[#{id}][written_on(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_456_written_on_3i" name="post[#{id}][written_on(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}

    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on", :index => id)
  end

  def test_date_select_with_auto_index
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)
    id = 123

    expected = %{<select id="post_123_written_on_1i" name="post[#{id}][written_on(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_123_written_on_2i" name="post[#{id}][written_on(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_123_written_on_3i" name="post[#{id}][written_on(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}
    expected << "</select>\n"

    assert_equal expected, date_select("post[]", "written_on")
  end

  def test_date_select_with_different_order
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)

    expected =  %{<select id="post_written_on_3i" name="post[written_on(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 15}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 6}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"

    expected <<  %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    1999.upto(2009) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 2004}>#{i}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on", :order => [:day, :month, :year])
  end

  def test_date_select_with_nil
    @post = Post.new

    start_year = Time.now.year-5
    end_year   = Time.now.year+5
    expected =   %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    start_year.upto(end_year) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == Time.now.year}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == Time.now.month}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"

    expected << %{<select id="post_written_on_3i" name="post[written_on(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == Time.now.day}>#{i}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on")
  end

  def test_date_select_with_nil_and_blank
    @post = Post.new

    start_year = Time.now.year-5
    end_year   = Time.now.year+5
    expected =   %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    expected << "<option value=\"\"></option>\n"
    start_year.upto(end_year) { |i| expected << %(<option value="#{i}">#{i}</option>\n) }
    expected << "</select>\n"

    expected << %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    expected << "<option value=\"\"></option>\n"
    1.upto(12) { |i| expected << %(<option value="#{i}">#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"

    expected << %{<select id="post_written_on_3i" name="post[written_on(3i)]">\n}
    expected << "<option value=\"\"></option>\n"
    1.upto(31) { |i| expected << %(<option value="#{i}">#{i}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on", :include_blank => true)
  end

  def test_date_select_cant_override_discard_hour
    @post = Post.new
    @post.written_on = Date.new(2004, 6, 15)

    expected = %{<select id="post_written_on_1i" name="post[written_on(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_written_on_2i" name="post[written_on(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_written_on_3i" name="post[written_on(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}
    expected << "</select>\n"

    assert_equal expected, date_select("post", "written_on", :discard_hour => false)
  end

  def test_time_select
    @post = Post.new
    @post.written_on = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<input type="hidden" id="post_written_on_1i" name="post[written_on(1i)]" value="2004" />\n}
    expected << %{<input type="hidden" id="post_written_on_2i" name="post[written_on(2i)]" value="6" />\n}
    expected << %{<input type="hidden" id="post_written_on_3i" name="post[written_on(3i)]" value="15" />\n}

    expected << %(<select id="post_written_on_4i" name="post[written_on(4i)]">\n)
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %(<select id="post_written_on_5i" name="post[written_on(5i)]">\n)
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, time_select("post", "written_on")
  end

  def test_time_select_with_seconds
    @post = Post.new
    @post.written_on = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<input type="hidden" id="post_written_on_1i" name="post[written_on(1i)]" value="2004" />\n}
    expected << %{<input type="hidden" id="post_written_on_2i" name="post[written_on(2i)]" value="6" />\n}
    expected << %{<input type="hidden" id="post_written_on_3i" name="post[written_on(3i)]" value="15" />\n}

    expected << %(<select id="post_written_on_4i" name="post[written_on(4i)]">\n)
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %(<select id="post_written_on_5i" name="post[written_on(5i)]">\n)
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %(<select id="post_written_on_6i" name="post[written_on(6i)]">\n)
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 35}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, time_select("post", "written_on", :include_seconds => true)
  end

  def test_datetime_select
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 16, 35)

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n}
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35" selected="selected">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n}
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at")
  end

  def test_datetime_select_within_fields_for
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 16, 35)

    _erbout = ''

    fields_for :post, @post do |f|
      _erbout.concat f.datetime_select(:updated_at)
    end

    expected = "<select id='post_updated_at_1i' name='post[updated_at(1i)]'>\n<option value='1999'>1999</option>\n<option value='2000'>2000</option>\n<option value='2001'>2001</option>\n<option value='2002'>2002</option>\n<option value='2003'>2003</option>\n<option selected='selected' value='2004'>2004</option>\n<option value='2005'>2005</option>\n<option value='2006'>2006</option>\n<option value='2007'>2007</option>\n<option value='2008'>2008</option>\n<option value='2009'>2009</option>\n</select>\n"
    expected << "<select id='post_updated_at_2i' name='post[updated_at(2i)]'>\n<option value='1'>January</option>\n<option value='2'>February</option>\n<option value='3'>March</option>\n<option value='4'>April</option>\n<option value='5'>May</option>\n<option selected='selected' value='6'>June</option>\n<option value='7'>July</option>\n<option value='8'>August</option>\n<option value='9'>September</option>\n<option value='10'>October</option>\n<option value='11'>November</option>\n<option value='12'>December</option>\n</select>\n"
    expected << "<select id='post_updated_at_3i' name='post[updated_at(3i)]'>\n<option value='1'>1</option>\n<option value='2'>2</option>\n<option value='3'>3</option>\n<option value='4'>4</option>\n<option value='5'>5</option>\n<option value='6'>6</option>\n<option value='7'>7</option>\n<option value='8'>8</option>\n<option value='9'>9</option>\n<option value='10'>10</option>\n<option value='11'>11</option>\n<option value='12'>12</option>\n<option value='13'>13</option>\n<option value='14'>14</option>\n<option selected='selected' value='15'>15</option>\n<option value='16'>16</option>\n<option value='17'>17</option>\n<option value='18'>18</option>\n<option value='19'>19</option>\n<option value='20'>20</option>\n<option value='21'>21</option>\n<option value='22'>22</option>\n<option value='23'>23</option>\n<option value='24'>24</option>\n<option value='25'>25</option>\n<option value='26'>26</option>\n<option value='27'>27</option>\n<option value='28'>28</option>\n<option value='29'>29</option>\n<option value='30'>30</option>\n<option value='31'>31</option>\n</select>\n"
   expected << " &mdash; <select id='post_updated_at_4i' name='post[updated_at(4i)]'>\n<option value='00'>00</option>\n<option value='01'>01</option>\n<option value='02'>02</option>\n<option value='03'>03</option>\n<option value='04'>04</option>\n<option value='05'>05</option>\n<option value='06'>06</option>\n<option value='07'>07</option>\n<option value='08'>08</option>\n<option value='09'>09</option>\n<option value='10'>10</option>\n<option value='11'>11</option>\n<option value='12'>12</option>\n<option value='13'>13</option>\n<option value='14'>14</option>\n<option value='15'>15</option>\n<option selected='selected' value='16'>16</option>\n<option value='17'>17</option>\n<option value='18'>18</option>\n<option value='19'>19</option>\n<option value='20'>20</option>\n<option value='21'>21</option>\n<option value='22'>22</option>\n<option value='23'>23</option>\n</select>\n"
  expected << " : <select id='post_updated_at_5i' name='post[updated_at(5i)]'>\n<option value='00'>00</option>\n<option value='01'>01</option>\n<option value='02'>02</option>\n<option value='03'>03</option>\n<option value='04'>04</option>\n<option value='05'>05</option>\n<option value='06'>06</option>\n<option value='07'>07</option>\n<option value='08'>08</option>\n<option value='09'>09</option>\n<option value='10'>10</option>\n<option value='11'>11</option>\n<option value='12'>12</option>\n<option value='13'>13</option>\n<option value='14'>14</option>\n<option value='15'>15</option>\n<option value='16'>16</option>\n<option value='17'>17</option>\n<option value='18'>18</option>\n<option value='19'>19</option>\n<option value='20'>20</option>\n<option value='21'>21</option>\n<option value='22'>22</option>\n<option value='23'>23</option>\n<option value='24'>24</option>\n<option value='25'>25</option>\n<option value='26'>26</option>\n<option value='27'>27</option>\n<option value='28'>28</option>\n<option value='29'>29</option>\n<option value='30'>30</option>\n<option value='31'>31</option>\n<option value='32'>32</option>\n<option value='33'>33</option>\n<option value='34'>34</option>\n<option selected='selected' value='35'>35</option>\n<option value='36'>36</option>\n<option value='37'>37</option>\n<option value='38'>38</option>\n<option value='39'>39</option>\n<option value='40'>40</option>\n<option value='41'>41</option>\n<option value='42'>42</option>\n<option value='43'>43</option>\n<option value='44'>44</option>\n<option value='45'>45</option>\n<option value='46'>46</option>\n<option value='47'>47</option>\n<option value='48'>48</option>\n<option value='49'>49</option>\n<option value='50'>50</option>\n<option value='51'>51</option>\n<option value='52'>52</option>\n<option value='53'>53</option>\n<option value='54'>54</option>\n<option value='55'>55</option>\n<option value='56'>56</option>\n<option value='57'>57</option>\n<option value='58'>58</option>\n<option value='59'>59</option>\n</select>\n"

    assert_dom_equal(expected, _erbout)
  end

  def test_date_select_with_zero_value_and_no_start_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+1) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected <<
%(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :end_year => Date.today.year+1, :prefix => "date[first]")
  end

  def test_date_select_with_zero_value_and_no_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    last_year = Time.now.year + 5
    2003.upto(last_year) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected <<
%(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :start_year => 2003, :prefix => "date[first]")
  end

  def test_date_select_with_zero_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected <<
%(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(0, :prefix => "date[first]")
  end

  def test_date_select_with_nil_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected <<
%(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_date(nil, :prefix => "date[first]")
  end

  def test_datetime_select_with_nil_value_and_no_start_and_end_year
    expected =  %(<select id="date_first_year" name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option value="#{y}">#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select id="date_first_month" name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_day" name="date[first][day]">\n)
    expected <<
%(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_hour" name="date[first][hour]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n)
    expected << "</select>\n"

    expected << %(<select id="date_first_minute" name="date[first][minute]">\n)
    expected << %(<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_datetime(nil, :prefix => "date[first]")
  end


  def test_datetime_select_with_options_index
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 16, 35)
    id = 456

    expected = %{<select id="post_456_updated_at_1i" name="post[#{id}][updated_at(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_456_updated_at_2i" name="post[#{id}][updated_at(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_456_updated_at_3i" name="post[#{id}][updated_at(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_456_updated_at_4i" name="post[#{id}][updated_at(4i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n}
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_456_updated_at_5i" name="post[#{id}][updated_at(5i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35" selected="selected">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n}
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :index => id)
  end

  def test_datetime_select_with_auto_index
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 16, 35)
    id = @post.id

    expected = %{<select id="post_123_updated_at_1i" name="post[#{id}][updated_at(1i)]">\n}
    expected << %{<option value="1999">1999</option>\n<option value="2000">2000</option>\n<option value="2001">2001</option>\n<option value="2002">2002</option>\n<option value="2003">2003</option>\n<option value="2004" selected="selected">2004</option>\n<option value="2005">2005</option>\n<option value="2006">2006</option>\n<option value="2007">2007</option>\n<option value="2008">2008</option>\n<option value="2009">2009</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_123_updated_at_2i" name="post[#{id}][updated_at(2i)]">\n}
    expected << %{<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6" selected="selected">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n}
    expected << "</select>\n"

    expected << %{<select id="post_123_updated_at_3i" name="post[#{id}][updated_at(3i)]">\n}
    expected << %{<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15" selected="selected">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n}
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_123_updated_at_4i" name="post[#{id}][updated_at(4i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16" selected="selected">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n}
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_123_updated_at_5i" name="post[#{id}][updated_at(5i)]">\n}
    expected << %{<option value="00">00</option>\n<option value="01">01</option>\n<option value="02">02</option>\n<option value="03">03</option>\n<option value="04">04</option>\n<option value="05">05</option>\n<option value="06">06</option>\n<option value="07">07</option>\n<option value="08">08</option>\n<option value="09">09</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n<option value="13">13</option>\n<option value="14">14</option>\n<option value="15">15</option>\n<option value="16">16</option>\n<option value="17">17</option>\n<option value="18">18</option>\n<option value="19">19</option>\n<option value="20">20</option>\n<option value="21">21</option>\n<option value="22">22</option>\n<option value="23">23</option>\n<option value="24">24</option>\n<option value="25">25</option>\n<option value="26">26</option>\n<option value="27">27</option>\n<option value="28">28</option>\n<option value="29">29</option>\n<option value="30">30</option>\n<option value="31">31</option>\n<option value="32">32</option>\n<option value="33">33</option>\n<option value="34">34</option>\n<option value="35" selected="selected">35</option>\n<option value="36">36</option>\n<option value="37">37</option>\n<option value="38">38</option>\n<option value="39">39</option>\n<option value="40">40</option>\n<option value="41">41</option>\n<option value="42">42</option>\n<option value="43">43</option>\n<option value="44">44</option>\n<option value="45">45</option>\n<option value="46">46</option>\n<option value="47">47</option>\n<option value="48">48</option>\n<option value="49">49</option>\n<option value="50">50</option>\n<option value="51">51</option>\n<option value="52">52</option>\n<option value="53">53</option>\n<option value="54">54</option>\n<option value="55">55</option>\n<option value="56">56</option>\n<option value="57">57</option>\n<option value="58">58</option>\n<option value="59">59</option>\n}
    expected << "</select>\n"

    assert_equal expected, datetime_select("post[]", "updated_at")
  end

  def test_datetime_select_with_seconds
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    1999.upto(2009) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 2004}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 6}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 15}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_6i" name="post[updated_at(6i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 35}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :include_seconds => true)
  end

  def test_datetime_select_discard_year
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n}
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 6}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 15}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :discard_year => true)
  end

  def test_datetime_select_discard_month
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    1999.upto(2009) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 2004}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n}
    expected << %{<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n}

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :discard_month => true)
  end

  def test_datetime_select_discard_year_and_month
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n}
    expected << %{<input type="hidden" id="post_updated_at_2i" name="post[updated_at(2i)]" value="6" />\n}
    expected << %{<input type="hidden" id="post_updated_at_3i" name="post[updated_at(3i)]" value="15" />\n}

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :discard_year => true, :discard_month => true)
  end

  def test_datetime_select_invalid_order
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 15}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 6}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    1999.upto(2009) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 2004}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :order => [:minute, :day, :hour, :month, :year, :second])
  end

  def test_datetime_select_discard_with_order
    @post = Post.new
    @post.updated_at = Time.local(2004, 6, 15, 15, 16, 35)

    expected = %{<input type="hidden" id="post_updated_at_1i" name="post[updated_at(1i)]" value="2004" />\n}
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 15}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 6}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :order => [:day, :month])
  end

  def test_datetime_select_with_default_value_as_time
    @post = Post.new
    @post.updated_at = nil

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    2001.upto(2011) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 2006}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 9}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 19}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 15}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 16}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :default => Time.local(2006, 9, 19, 15, 16, 35))
  end

  def test_include_blank_overrides_default_option
    @post = Post.new
    @post.updated_at = nil

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    expected << %(<option value=""></option>\n)
    2002.upto(2012) { |i| expected << %(<option value="#{i}">#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    expected << %(<option value=""></option>\n)
    1.upto(12) { |i| expected << %(<option value="#{i}">#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    expected << %(<option value=""></option>\n)
    1.upto(31) { |i| expected << %(<option value="#{i}">#{i}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, date_select("post", "updated_at", :default => Time.local(2006, 9, 19, 15, 16, 35), :include_blank => true)
  end

  def test_datetime_select_with_default_value_as_hash
    @post = Post.new
    @post.updated_at = nil

    expected = %{<select id="post_updated_at_1i" name="post[updated_at(1i)]">\n}
    (Time.now.year - 5).upto(Time.now.year + 5) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == Time.now.year}>#{i}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_2i" name="post[updated_at(2i)]">\n}
    1.upto(12) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == 10}>#{Date::MONTHNAMES[i]}</option>\n) }
    expected << "</select>\n"
    expected << %{<select id="post_updated_at_3i" name="post[updated_at(3i)]">\n}
    1.upto(31) { |i| expected << %(<option value="#{i}"#{' selected="selected"' if i == Time.now.day}>#{i}</option>\n) }
    expected << "</select>\n"

    expected << " &mdash; "

    expected << %{<select id="post_updated_at_4i" name="post[updated_at(4i)]">\n}
    0.upto(23) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 9}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"
    expected << " : "
    expected << %{<select id="post_updated_at_5i" name="post[updated_at(5i)]">\n}
    0.upto(59) { |i| expected << %(<option value="#{leading_zero_on_single_digits(i)}"#{' selected="selected"' if i == 42}>#{leading_zero_on_single_digits(i)}</option>\n) }
    expected << "</select>\n"

    assert_equal expected, datetime_select("post", "updated_at", :default => { :month => 10, :minute => 42, :hour => 9 })
  end
end
