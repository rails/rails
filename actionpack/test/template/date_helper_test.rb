require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/date_helper'

class DateHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::DateHelper

  def test_distance_in_words
    from = Time.mktime(2004, 3, 6, 21, 41, 18)
    
    assert_equal "less than a minute", distance_of_time_in_words(from, Time.mktime(2004, 3, 6, 21, 41, 25))
    assert_equal "5 minutes", distance_of_time_in_words(from, Time.mktime(2004, 3, 6, 21, 46, 25))
    assert_equal "about 1 hour", distance_of_time_in_words(from, Time.mktime(2004, 3, 6, 22, 47, 25))
    assert_equal "about 3 hours", distance_of_time_in_words(from, Time.mktime(2004, 3, 7, 0, 41))
    assert_equal "about 4 hours", distance_of_time_in_words(from, Time.mktime(2004, 3, 7, 1, 20))
    assert_equal "2 days", distance_of_time_in_words(from, Time.mktime(2004, 3, 9, 15, 40))
  end

  def test_select_day
    expected = %(<select name="date[day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_day(Time.mktime(2003, 8, 16))
    assert_equal expected, select_day(16)
  end

  def test_select_day_with_blank
    expected = %(<select name="date[day]">\n)
    expected <<
%(<option></option>\n<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_day(Time.mktime(2003, 8, 16), :include_blank => true)
    assert_equal expected, select_day(16, :include_blank => true)
  end
  
  def test_select_month
    expected = %(<select name="date[month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16))
    assert_equal expected, select_month(8)
  end

  def test_select_month_with_numbers
    expected = %(<select name="date[month]">\n)
    expected << %(<option value="1">1</option>\n<option value="2">2</option>\n<option value="3">3</option>\n<option value="4">4</option>\n<option value="5">5</option>\n<option value="6">6</option>\n<option value="7">7</option>\n<option value="8" selected="selected">8</option>\n<option value="9">9</option>\n<option value="10">10</option>\n<option value="11">11</option>\n<option value="12">12</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :use_month_numbers => true)
    assert_equal expected, select_month(8, :use_month_numbers => true)
  end

  def test_select_month_with_numbers_and_names
    expected = %(<select name="date[month]">\n)
    expected << %(<option value="1">1 - January</option>\n<option value="2">2 - February</option>\n<option value="3">3 - March</option>\n<option value="4">4 - April</option>\n<option value="5">5 - May</option>\n<option value="6">6 - June</option>\n<option value="7">7 - July</option>\n<option value="8" selected="selected">8 - August</option>\n<option value="9">9 - September</option>\n<option value="10">10 - October</option>\n<option value="11">11 - November</option>\n<option value="12">12 - December</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_month(Time.mktime(2003, 8, 16), :add_month_numbers => true)
    assert_equal expected, select_month(8, :add_month_numbers => true)
  end

  def test_select_year
    expected = %(<select name="date[year]">\n)
    expected << %(<option selected="selected">2003</option>\n<option>2004</option>\n<option>2005</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_year(Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005)
    assert_equal expected, select_year(2003, :start_year => 2003, :end_year => 2005)
  end
  
  def test_select_year_with_type_discarding
    expected = %(<select name="date_year">\n)
    expected << %(<option selected="selected">2003</option>\n<option>2004</option>\n<option>2005</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_year(
      Time.mktime(2003, 8, 16), :prefix => "date_year", :discard_type => true, :start_year => 2003, :end_year => 2005)
    assert_equal expected, select_year(
      2003, :prefix => "date_year", :discard_type => true, :start_year => 2003, :end_year => 2005)
  end

  def test_select_hour
    expected = %(<select name="date[hour]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option>04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option selected="selected">08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_hour(Time.mktime(2003, 8, 16, 8, 4, 18))
  end

  def test_select_minute
    expected = %(<select name="date[minute]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option selected="selected">04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option>08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n<option>32</option>\n<option>33</option>\n<option>34</option>\n<option>35</option>\n<option>36</option>\n<option>37</option>\n<option>38</option>\n<option>39</option>\n<option>40</option>\n<option>41</option>\n<option>42</option>\n<option>43</option>\n<option>44</option>\n<option>45</option>\n<option>46</option>\n<option>47</option>\n<option>48</option>\n<option>49</option>\n<option>50</option>\n<option>51</option>\n<option>52</option>\n<option>53</option>\n<option>54</option>\n<option>55</option>\n<option>56</option>\n<option>57</option>\n<option>58</option>\n<option>59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_minute(Time.mktime(2003, 8, 16, 8, 4, 18))
  end

  def test_select_second
    expected = %(<select name="date[second]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option>04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option>08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option selected="selected">18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n<option>32</option>\n<option>33</option>\n<option>34</option>\n<option>35</option>\n<option>36</option>\n<option>37</option>\n<option>38</option>\n<option>39</option>\n<option>40</option>\n<option>41</option>\n<option>42</option>\n<option>43</option>\n<option>44</option>\n<option>45</option>\n<option>46</option>\n<option>47</option>\n<option>48</option>\n<option>49</option>\n<option>50</option>\n<option>51</option>\n<option>52</option>\n<option>53</option>\n<option>54</option>\n<option>55</option>\n<option>56</option>\n<option>57</option>\n<option>58</option>\n<option>59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_second(Time.mktime(2003, 8, 16, 8, 4, 18))
  end
  
  
  def test_select_date
    expected =  %(<select name="date[first][year]">\n)
    expected << %(<option selected="selected">2003</option>\n<option>2004</option>\n<option>2005</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(
      Time.mktime(2003, 8, 16), :start_year => 2003, :end_year => 2005, :prefix => "date[first]"
    )
  end
  
  def test_select_date_with_no_start_year
    expected =  %(<select name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+1) do |y|
      if y == Date.today.year 
        expected << %(<option selected="selected">#{y}</option>\n)
      else
        expected << %(<option>#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(
      Time.mktime(Date.today.year, 8, 16), :end_year => Date.today.year+1, :prefix => "date[first]"
    )
  end

  def test_select_date_with_no_end_year
    expected =  %(<select name="date[first][year]">\n)
    2003.upto(2008) do |y|
      if y == 2003
        expected << %(<option selected="selected">#{y}</option>\n)
      else
        expected << %(<option>#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(
      Time.mktime(2003, 8, 16), :start_year => 2003, :prefix => "date[first]"
    )
  end

  def test_select_date_with_no_start_or_end_year
    expected =  %(<select name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) do |y|
      if y == Date.today.year 
        expected << %(<option selected="selected">#{y}</option>\n)
      else
        expected << %(<option>#{y}</option>\n)
      end
    end
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8" selected="selected">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option selected="selected">16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(
      Time.mktime(Date.today.year, 8, 16), :prefix => "date[first]"
    )
  end

  def test_select_time_with_seconds
    expected = %(<select name="date[hour]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option>04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option selected="selected">08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[minute]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option selected="selected">04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option>08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n<option>32</option>\n<option>33</option>\n<option>34</option>\n<option>35</option>\n<option>36</option>\n<option>37</option>\n<option>38</option>\n<option>39</option>\n<option>40</option>\n<option>41</option>\n<option>42</option>\n<option>43</option>\n<option>44</option>\n<option>45</option>\n<option>46</option>\n<option>47</option>\n<option>48</option>\n<option>49</option>\n<option>50</option>\n<option>51</option>\n<option>52</option>\n<option>53</option>\n<option>54</option>\n<option>55</option>\n<option>56</option>\n<option>57</option>\n<option>58</option>\n<option>59</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[second]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option>04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option>08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option selected="selected">18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n<option>32</option>\n<option>33</option>\n<option>34</option>\n<option>35</option>\n<option>36</option>\n<option>37</option>\n<option>38</option>\n<option>39</option>\n<option>40</option>\n<option>41</option>\n<option>42</option>\n<option>43</option>\n<option>44</option>\n<option>45</option>\n<option>46</option>\n<option>47</option>\n<option>48</option>\n<option>49</option>\n<option>50</option>\n<option>51</option>\n<option>52</option>\n<option>53</option>\n<option>54</option>\n<option>55</option>\n<option>56</option>\n<option>57</option>\n<option>58</option>\n<option>59</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :include_seconds => true)
  end

  def test_select_time_without_seconds
    expected = %(<select name="date[hour]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option>04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option selected="selected">08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[minute]">\n)
    expected << %(<option>00</option>\n<option>01</option>\n<option>02</option>\n<option>03</option>\n<option selected="selected">04</option>\n<option>05</option>\n<option>06</option>\n<option>07</option>\n<option>08</option>\n<option>09</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n<option>32</option>\n<option>33</option>\n<option>34</option>\n<option>35</option>\n<option>36</option>\n<option>37</option>\n<option>38</option>\n<option>39</option>\n<option>40</option>\n<option>41</option>\n<option>42</option>\n<option>43</option>\n<option>44</option>\n<option>45</option>\n<option>46</option>\n<option>47</option>\n<option>48</option>\n<option>49</option>\n<option>50</option>\n<option>51</option>\n<option>52</option>\n<option>53</option>\n<option>54</option>\n<option>55</option>\n<option>56</option>\n<option>57</option>\n<option>58</option>\n<option>59</option>\n)
    expected << "</select>\n"

    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18))
    assert_equal expected, select_time(Time.mktime(2003, 8, 16, 8, 4, 18), :include_seconds => false)
  end

  def test_date_select_with_zero_value
    expected =  %(<select name="date[first][year]">\n)
    expected << %(<option>2003</option>\n<option>2004</option>\n<option>2005</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(0, :start_year => 2003, :end_year => 2005, :prefix => "date[first]")
  end

  def test_date_select_with_zero_value_and_no_start_year
    expected =  %(<select name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+1) { |y| expected << %(<option>#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(0, :end_year => Date.today.year+1, :prefix => "date[first]")
  end

  def test_date_select_with_zero_value_and_no_end_year
    expected =  %(<select name="date[first][year]">\n)
    2003.upto(2010) { |y| expected << %(<option>#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(0, :start_year => 2003, :prefix => "date[first]")
  end
  
  def test_date_select_with_zero_value_and_no_start_and_end_year
    expected =  %(<select name="date[first][year]">\n)
    (Date.today.year-5).upto(Date.today.year+5) { |y| expected << %(<option>#{y}</option>\n) }
    expected << "</select>\n"

    expected << %(<select name="date[first][month]">\n)
    expected << %(<option value="1">January</option>\n<option value="2">February</option>\n<option value="3">March</option>\n<option value="4">April</option>\n<option value="5">May</option>\n<option value="6">June</option>\n<option value="7">July</option>\n<option value="8">August</option>\n<option value="9">September</option>\n<option value="10">October</option>\n<option value="11">November</option>\n<option value="12">December</option>\n)
    expected << "</select>\n"

    expected << %(<select name="date[first][day]">\n)
    expected <<
%(<option>1</option>\n<option>2</option>\n<option>3</option>\n<option>4</option>\n<option>5</option>\n<option>6</option>\n<option>7</option>\n<option>8</option>\n<option>9</option>\n<option>10</option>\n<option>11</option>\n<option>12</option>\n<option>13</option>\n<option>14</option>\n<option>15</option>\n<option>16</option>\n<option>17</option>\n<option>18</option>\n<option>19</option>\n<option>20</option>\n<option>21</option>\n<option>22</option>\n<option>23</option>\n<option>24</option>\n<option>25</option>\n<option>26</option>\n<option>27</option>\n<option>28</option>\n<option>29</option>\n<option>30</option>\n<option>31</option>\n)
    expected << "</select>\n"
    
    assert_equal expected, select_date(0, :prefix => "date[first]")
  end

end
