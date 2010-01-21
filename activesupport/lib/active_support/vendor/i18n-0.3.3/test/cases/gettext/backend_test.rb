# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'i18n/backend/gettext'
require 'i18n/helpers/gettext'

class I18nGettextBackendTest < Test::Unit::TestCase
  include I18n::Helpers::Gettext

  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Gettext
  end

  def setup
    I18n.backend = Backend.new
    I18n.locale = :en
    I18n.load_path = ["#{locales_dir}/de.po"]
  end

  def teardown
    I18n.load_path = nil
    I18n.backend = nil
  end

  def test_backend_loads_po_file
    I18n.backend.send(:init_translations)
    assert I18n.backend.send(:translations)[:de][:"Axis"]
  end

  def test_looks_up_a_translation
    I18n.locale = :de
    assert_equal 'Auto', gettext('car')
  end

  def test_uses_default_translation
    assert_equal 'car', gettext('car')
  end

  def test_looks_up_a_namespaced_translation
    I18n.locale = :de
    assert_equal 'Räderzahl', sgettext('Car|Wheels count')
    assert_equal 'Räderzahl', pgettext('Car', 'Wheels count')
  end

  def test_uses_namespaced_default_translation
    assert_equal 'Wheels count', sgettext('Car|Wheels count')
    assert_equal 'Wheels count', pgettext('Car', 'Wheels count')
  end

  def test_pluralizes_entry
    I18n.locale = :de
    assert_equal 'Achse', ngettext('Axis', 'Axis', 1)
    assert_equal 'Achsen', ngettext('Axis', 'Axis', 2)
  end

  def test_pluralizes_default_entry
    assert_equal 'Axis', ngettext('Axis', 'Axis', 1)
    assert_equal 'Axis', ngettext('Axis', 'Axis', 2)
  end

  def test_pluralizes_namespaced_entry
    I18n.locale = :de
    assert_equal 'Rad',   nsgettext('Car|wheel', 'wheels', 1)
    assert_equal 'Räder', nsgettext('Car|wheel', 'wheels', 2)
    assert_equal 'Rad',   npgettext('Car', 'wheel', 'wheels', 1)
    assert_equal 'Räder', npgettext('Car', 'wheel', 'wheels', 2)
  end

  def test_pluralizes_namespaced_default_entry
    assert_equal 'wheel',  nsgettext('Car|wheel', 'wheels', 1)
    assert_equal 'wheels', nsgettext('Car|wheel', 'wheels', 2)
    assert_equal 'wheel',  npgettext('Car', 'wheel', 'wheels', 1)
    assert_equal 'wheels', npgettext('Car', 'wheel', 'wheels', 2)
  end

  def test_pluralizes_namespaced_entry_with_alternative_syntax
    I18n.locale = :de
    assert_equal 'Rad',   nsgettext(['Car|wheel', 'wheels'], 1)
    assert_equal 'Räder', nsgettext(['Car|wheel', 'wheels'], 2)
    assert_equal 'Rad',   npgettext('Car', ['wheel', 'wheels'], 1)
    assert_equal 'Räder', npgettext('Car', ['wheel', 'wheels'], 2)
  end
  
  def test_ngettextpluralizes_entry_with_dots
    I18n.locale = :de
    assert_equal 'Auf 1 Achse.', n_("On %{count} wheel.", "On %{count} wheels.", 1)
    assert_equal 'Auf 2 Achsen.', n_("On %{count} wheel.", "On %{count} wheels.", 2)
  end
  
end
