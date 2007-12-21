require 'cgi'
require 'erb'
require 'action_view/helpers/form_helper'

module ActionView
  module Helpers
    # Provides a number of methods for turning different kinds of containers into a set of option tags.
    # == Options
    # The <tt>collection_select</tt>, <tt>country_select</tt>, <tt>select</tt>,
    # and <tt>time_zone_select</tt> methods take an <tt>options</tt> parameter,
    # a hash.
    #
    # * <tt>:include_blank</tt> - set to true or a prompt string if the first option element of the select element is a blank. Useful if there is not a default value required for the select element.
    #
    # For example,
    #
    #   select("post", "category", Post::CATEGORIES, {:include_blank => true})
    #
    # could become:
    #
    #   <select name="post[category]">
    #     <option></option>
    #     <option>joke</option>
    #     <option>poem</option>
    #   </select>
    #
    # Another common case is a select tag for an <tt>belongs_to</tt>-associated object.
    #
    # Example with @post.person_id => 2:
    #
    #   select("post", "person_id", Person.find(:all).collect {|p| [ p.name, p.id ] }, {:include_blank => 'None'})
    #
    # could become:
    #
    #   <select name="post[person_id]">
    #     <option value="">None</option>
    #     <option value="1">David</option>
    #     <option value="2" selected="selected">Sam</option>
    #     <option value="3">Tobias</option>
    #   </select>
    #
    # * <tt>:prompt</tt> - set to true or a prompt string. When the select element doesn't have a value yet, this prepends an option with a generic prompt -- "Please select" -- or the given prompt string.
    #
    # Example:
    #
    #   select("post", "person_id", Person.find(:all).collect {|p| [ p.name, p.id ] }, {:prompt => 'Select Person'})
    #
    # could become:
    #
    #   <select name="post[person_id]">
    #     <option value="">Select Person</option>
    #     <option value="1">David</option>
    #     <option value="2">Sam</option>
    #     <option value="3">Tobias</option>
    #   </select>
    module FormOptionsHelper
      include ERB::Util

      # Create a select tag and a series of contained option tags for the provided object and method.
      # The option currently held by the object will be selected, provided that the object is available.
      # See options_for_select for the required format of the choices parameter.
      #
      # Example with @post.person_id => 1:
      #   select("post", "person_id", Person.find(:all).collect {|p| [ p.name, p.id ] }, { :include_blank => true })
      #
      # could become:
      #
      #   <select name="post[person_id]">
      #     <option value=""></option>
      #     <option value="1" selected="selected">David</option>
      #     <option value="2">Sam</option>
      #     <option value="3">Tobias</option>
      #   </select>
      #
      # This can be used to provide a default set of options in the standard way: before rendering the create form, a
      # new model instance is assigned the default options and bound to @model_name. Usually this model is not saved
      # to the database. Instead, a second model object is created when the create request is received.
      # This allows the user to submit a form page more than once with the expected results of creating multiple records.
      # In addition, this allows a single partial to be used to generate form inputs for both edit and create forms.
      #
      # By default, post.person_id is the selected option.  Specify :selected => value to use a different selection
      # or :selected => nil to leave all options unselected.
      def select(object, method, choices, options = {}, html_options = {})
        InstanceTag.new(object, method, self, nil, options.delete(:object)).to_select_tag(choices, options, html_options)
      end

      # Returns <tt><select></tt> and <tt><option></tt> tags for the collection of existing return values of
      # +method+ for +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made without including <tt>:prompt</tt>
      # or <tt>:include_blank</tt> in the +options+ hash.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are methods to be called on each member
      # of +collection+. The return values are used as the +value+ attribute and contents of each
      # <tt><option></tt> tag, respectively.
      # 
      # Example object structure for use with this method:
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #   end
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated +Author+ for an instance of +Post+, <tt>@post</tt>):
      #   collection_select(:post, :author_id, Author.find(:all), :id, :name_with_initial, {:prompt => true})
      #
      # If <tt>@post.author_id</tt> is already <tt>1</tt>, this would return:
      #   <select name="post[author_id]">
      #     <option value="">Please select</option>
      #     <option value="1" selected="selected">D. Heinemeier Hansson</option>
      #     <option value="2">D. Thomas</option>
      #     <option value="3">M. Clark</option>
      #   </select>
      def collection_select(object, method, collection, value_method, text_method, options = {}, html_options = {})
        InstanceTag.new(object, method, self, nil, options.delete(:object)).to_collection_select_tag(collection, value_method, text_method, options, html_options)
      end

      # Return select and option tags for the given object and method, using country_options_for_select to generate the list of option tags.
      def country_select(object, method, priority_countries = nil, options = {}, html_options = {})
        InstanceTag.new(object, method, self, nil, options.delete(:object)).to_country_select_tag(priority_countries, options, html_options)
      end

      # Return select and option tags for the given object and method, using
      # #time_zone_options_for_select to generate the list of option tags.
      #
      # In addition to the <tt>:include_blank</tt> option documented above,
      # this method also supports a <tt>:model</tt> option, which defaults
      # to TimeZone. This may be used by users to specify a different time
      # zone model object. (See #time_zone_options_for_select for more
      # information.)
      # Finally, this method supports a <tt>:default</tt> option, which selects
      # a default TimeZone if the object's time zone is nil.
      #
      # Examples:
      #   time_zone_select( "user", "time_zone", nil, :include_blank => true)
      #
      #   time_zone_select( "user", "time_zone", nil, :default => "Pacific Time (US & Canada)" )
      #
      #   time_zone_select( "user", 'time_zone', TimeZone.us_zones, :default => "Pacific Time (US & Canada)")
      #
      #   time_zone_select( "user", "time_zone", TZInfo::Timezone.all.sort, :model => TZInfo::Timezone)
      def time_zone_select(object, method, priority_zones = nil, options = {}, html_options = {})
        InstanceTag.new(object, method, self, nil, options.delete(:object)).to_time_zone_select_tag(priority_zones, options, html_options)
      end

      # Accepts a container (hash, array, enumerable, your type) and returns a string of option tags. Given a container
      # where the elements respond to first and last (such as a two-element array), the "lasts" serve as option values and
      # the "firsts" as option text. Hashes are turned into this form automatically, so the keys become "firsts" and values
      # become lasts. If +selected+ is specified, the matching "last" or element will get the selected option-tag.  +Selected+
      # may also be an array of values to be selected when using a multiple select.
      #
      # Examples (call, result):
      #   options_for_select([["Dollar", "$"], ["Kroner", "DKK"]])
      #     <option value="$">Dollar</option>\n<option value="DKK">Kroner</option>
      #
      #   options_for_select([ "VISA", "MasterCard" ], "MasterCard")
      #     <option>VISA</option>\n<option selected="selected">MasterCard</option>
      #
      #   options_for_select({ "Basic" => "$20", "Plus" => "$40" }, "$40")
      #     <option value="$20">Basic</option>\n<option value="$40" selected="selected">Plus</option>
      #
      #   options_for_select([ "VISA", "MasterCard", "Discover" ], ["VISA", "Discover"])
      #     <option selected="selected">VISA</option>\n<option>MasterCard</option>\n<option selected="selected">Discover</option>
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def options_for_select(container, selected = nil)
        container = container.to_a if Hash === container

        options_for_select = container.inject([]) do |options, element|
          text, value = option_text_and_value(element)
          selected_attribute = ' selected="selected"' if option_value_selected?(value, selected)
          options << %(<option value="#{html_escape(value.to_s)}"#{selected_attribute}>#{html_escape(text.to_s)}</option>)
        end

        options_for_select.join("\n")
      end

      # Returns a string of option tags that have been compiled by iterating over the +collection+ and assigning the
      # the result of a call to the +value_method+ as the option value and the +text_method+ as the option text.
      # If +selected+ is specified, the element returning a match on +value_method+ will get the selected option tag.
      #
      # Example (call, result). Imagine a loop iterating over each +person+ in <tt>@project.people</tt> to generate an input tag:
      #   options_from_collection_for_select(@project.people, "id", "name")
      #     <option value="#{person.id}">#{person.name}</option>
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def options_from_collection_for_select(collection, value_method, text_method, selected = nil)
        options = collection.map do |element|
          [element.send(text_method), element.send(value_method)]
        end
        options_for_select(options, selected)
      end

      # Returns a string of <tt><option></tt> tags, like <tt>#options_from_collection_for_select</tt>, but
      # groups them by <tt><optgroup></tt> tags based on the object relationships of the arguments.
      #
      # Parameters:
      # +collection+::          An array of objects representing the <tt><optgroup></tt> tags
      # +group_method+::        The name of a method which, when called on a member of +collection+, returns an
      #                         array of child objects representing the <tt><option></tt> tags
      # +group_label_method+::  The name of a method which, when called on a member of +collection+, returns a
      #                         string to be used as the +label+ attribute for its <tt><optgroup></tt> tag
      # +option_key_method+::   The name of a method which, when called on a child object of a member of
      #                         +collection+, returns a value to be used as the +value+ attribute for its
      #                         <tt><option></tt> tag
      # +option_value_method+:: The name of a method which, when called on a child object of a member of
      #                         +collection+, returns a value to be used as the contents of its
      #                         <tt><option></tt> tag
      # +selected_key+::        A value equal to the +value+ attribute for one of the <tt><option></tt> tags,
      #                         which will have the +selected+ attribute set. Corresponds to the return value
      #                         of one of the calls to +option_key_method+. If +nil+, no selection is made.
      #
      # Example object structure for use with this method:
      #   class Continent < ActiveRecord::Base
      #     has_many :countries
      #     # attribs: id, name
      #   end
      #   class Country < ActiveRecord::Base
      #     belongs_to :continent
      #     # attribs: id, name, continent_id
      #   end
      #
      # Sample usage:
      #   option_groups_from_collection_for_select(@continents, :countries, :name, :id, :name, 3)
      #
      # Possible output:
      #   <optgroup label="Africa">
      #     <option value="1">Egypt</option>
      #     <option value="4">Rwanda</option>
      #     ...
      #   </optgroup>
      #   <optgroup label="Asia">
      #     <option value="3" selected="selected">China</option>
      #     <option value="12">India</option>
      #     <option value="5">Japan</option>
      #     ...
      #   </optgroup>
      #
      # <b>Note:</b> Only the <tt><optgroup></tt> and <tt><option></tt> tags are returned, so you still have to
      # wrap the output in an appropriate <tt><select></tt> tag.
      def option_groups_from_collection_for_select(collection, group_method, group_label_method, option_key_method, option_value_method, selected_key = nil)
        collection.inject("") do |options_for_select, group|
          group_label_string = eval("group.#{group_label_method}")
          options_for_select += "<optgroup label=\"#{html_escape(group_label_string)}\">"
          options_for_select += options_from_collection_for_select(eval("group.#{group_method}"), option_key_method, option_value_method, selected_key)
          options_for_select += '</optgroup>'
        end
      end

      # Returns a string of option tags for pretty much any country in the world. Supply a country name as +selected+ to
      # have it marked as the selected option tag. You can also supply an array of countries as +priority_countries+, so
      # that they will be listed above the rest of the (long) list.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def country_options_for_select(selected = nil, priority_countries = nil)
        country_options = ""

        if priority_countries
          country_options += options_for_select(priority_countries, selected)
          country_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n"
        end

        return country_options + options_for_select(COUNTRIES, selected)
      end

      # Returns a string of option tags for pretty much any time zone in the
      # world. Supply a TimeZone name as +selected+ to have it marked as the
      # selected option tag. You can also supply an array of TimeZone objects
      # as +priority_zones+, so that they will be listed above the rest of the
      # (long) list. (You can use TimeZone.us_zones as a convenience for
      # obtaining a list of the US time zones.)
      #
      # The +selected+ parameter must be either +nil+, or a string that names
      # a TimeZone.
      #
      # By default, +model+ is the TimeZone constant (which can be obtained
      # in ActiveRecord as a value object). The only requirement is that the
      # +model+ parameter be an object that responds to #all, and returns
      # an array of objects that represent time zones.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in
      # a regular HTML select tag.
      def time_zone_options_for_select(selected = nil, priority_zones = nil, model = TimeZone)
        zone_options = ""

        zones = model.all
        convert_zones = lambda { |list| list.map { |z| [ z.to_s, z.name ] } }

        if priority_zones
          zone_options += options_for_select(convert_zones[priority_zones], selected)
          zone_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n"

          zones = zones.reject { |z| priority_zones.include?( z ) }
        end

        zone_options += options_for_select(convert_zones[zones], selected)
        zone_options
      end

      private
        def option_text_and_value(option)
          # Options are [text, value] pairs or strings used for both.
          if !option.is_a?(String) and option.respond_to?(:first) and option.respond_to?(:last)
            [option.first, option.last]
          else
            [option, option]
          end
        end

        def option_value_selected?(value, selected)
          if selected.respond_to?(:include?) && !selected.is_a?(String)
            selected.include? value
          else
            value == selected
          end
        end

        # All the countries included in the country_options output.
        COUNTRIES = ["Afghanistan", "Aland Islands", "Albania", "Algeria", "American Samoa", "Andorra", "Angola",
          "Anguilla", "Antarctica", "Antigua And Barbuda", "Argentina", "Armenia", "Aruba", "Australia", "Austria",
          "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin",
          "Bermuda", "Bhutan", "Bolivia", "Bosnia and Herzegowina", "Botswana", "Bouvet Island", "Brazil",
          "British Indian Ocean Territory", "Brunei Darussalam", "Bulgaria", "Burkina Faso", "Burundi", "Cambodia",
          "Cameroon", "Canada", "Cape Verde", "Cayman Islands", "Central African Republic", "Chad", "Chile", "China",
          "Christmas Island", "Cocos (Keeling) Islands", "Colombia", "Comoros", "Congo",
          "Congo, the Democratic Republic of the", "Cook Islands", "Costa Rica", "Cote d'Ivoire", "Croatia", "Cuba",
          "Cyprus", "Czech Republic", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt",
          "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Ethiopia", "Falkland Islands (Malvinas)",
          "Faroe Islands", "Fiji", "Finland", "France", "French Guiana", "French Polynesia",
          "French Southern Territories", "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Gibraltar", "Greece", "Greenland", "Grenada", "Guadeloupe", "Guam", "Guatemala", "Guernsey", "Guinea",
          "Guinea-Bissau", "Guyana", "Haiti", "Heard and McDonald Islands", "Holy See (Vatican City State)",
          "Honduras", "Hong Kong", "Hungary", "Iceland", "India", "Indonesia", "Iran, Islamic Republic of", "Iraq",
          "Ireland", "Isle of Man", "Israel", "Italy", "Jamaica", "Japan", "Jersey", "Jordan", "Kazakhstan", "Kenya",
          "Kiribati", "Korea, Democratic People's Republic of", "Korea, Republic of", "Kuwait", "Kyrgyzstan",
          "Lao People's Democratic Republic", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libyan Arab Jamahiriya",
          "Liechtenstein", "Lithuania", "Luxembourg", "Macao", "Macedonia, The Former Yugoslav Republic Of",
          "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Martinique",
          "Mauritania", "Mauritius", "Mayotte", "Mexico", "Micronesia, Federated States of", "Moldova, Republic of",
          "Monaco", "Mongolia", "Montenegro", "Montserrat", "Morocco", "Mozambique", "Myanmar", "Namibia", "Nauru",
          "Nepal", "Netherlands", "Netherlands Antilles", "New Caledonia", "New Zealand", "Nicaragua", "Niger",
          "Nigeria", "Niue", "Norfolk Island", "Northern Mariana Islands", "Norway", "Oman", "Pakistan", "Palau",
          "Palestinian Territory, Occupied", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines",
          "Pitcairn", "Poland", "Portugal", "Puerto Rico", "Qatar", "Reunion", "Romania", "Russian Federation",
          "Rwanda", "Saint Barthelemy", "Saint Helena", "Saint Kitts and Nevis", "Saint Lucia",
          "Saint Pierre and Miquelon", "Saint Vincent and the Grenadines", "Samoa", "San Marino",
          "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore",
          "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa",
          "South Georgia and the South Sandwich Islands", "Spain", "Sri Lanka", "Sudan", "Suriname",
          "Svalbard and Jan Mayen", "Swaziland", "Sweden", "Switzerland", "Syrian Arab Republic",
          "Taiwan, Province of China", "Tajikistan", "Tanzania, United Republic of", "Thailand", "Timor-Leste",
          "Togo", "Tokelau", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan",
          "Turks and Caicos Islands", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom",
          "United States", "United States Minor Outlying Islands", "Uruguay", "Uzbekistan", "Vanuatu", "Venezuela",
          "Viet Nam", "Virgin Islands, British", "Virgin Islands, U.S.", "Wallis and Futuna", "Western Sahara",
          "Yemen", "Zambia", "Zimbabwe"] unless const_defined?("COUNTRIES")
    end

    class InstanceTag #:nodoc:
      include FormOptionsHelper

      def to_select_tag(choices, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        content_tag("select", add_options(options_for_select(choices, selected_value), options, selected_value), html_options)
      end

      def to_collection_select_tag(collection, value_method, text_method, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag(
          "select", add_options(options_from_collection_for_select(collection, value_method, text_method, value), options, value), html_options
        )
      end

      def to_country_select_tag(priority_countries, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select",
          add_options(
            country_options_for_select(value, priority_countries),
            options, value
          ), html_options
        )
      end

      def to_time_zone_select_tag(priority_zones, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select",
          add_options(
            time_zone_options_for_select(value || options[:default], priority_zones, options[:model] || TimeZone),
            options, value
          ), html_options
        )
      end

      private
        def add_options(option_tags, options, value = nil)
          if options[:include_blank]
            option_tags = "<option value=\"\">#{options[:include_blank] if options[:include_blank].kind_of?(String)}</option>\n" + option_tags
          end
          if value.blank? && options[:prompt]
            ("<option value=\"\">#{options[:prompt].kind_of?(String) ? options[:prompt] : 'Please select'}</option>\n") + option_tags
          else
            option_tags
          end
        end
    end

    class FormBuilder
      def select(method, choices, options = {}, html_options = {})
        @template.select(@object_name, method, choices, options.merge(:object => @object), html_options)
      end

      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_select(@object_name, method, collection, value_method, text_method, options.merge(:object => @object), html_options)
      end

      def country_select(method, priority_countries = nil, options = {}, html_options = {})
        @template.country_select(@object_name, method, priority_countries, options.merge(:object => @object), html_options)
      end

      def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
        @template.time_zone_select(@object_name, method, priority_zones, options.merge(:object => @object), html_options)
      end
    end
  end
end
