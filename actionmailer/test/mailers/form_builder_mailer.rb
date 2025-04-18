# frozen_string_literal: true

class FormBuilderMailer < ActionMailer::Base
  class SpecializedFormBuilder < ActionView::Helpers::FormBuilder
    def message
      "hi from SpecializedFormBuilder"
    end
  end

  default_form_builder SpecializedFormBuilder

  def welcome
    mail(to: "email@example.com")
  end
end
