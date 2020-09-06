# frozen_string_literal: true

class BaseMailer < ActionMailer::Base
  self.mailer_name = 'base_mailer'

  default to: 'system@test.lindsaar.net',
          from: 'jose@test.plataformatec.com',
          reply_to: email_address_with_name('mikel@test.lindsaar.net', 'Mikel')

  def welcome(hash = {})
    headers['X-SPAM'] = 'Not SPAM'
    mail({ subject: 'The first email on new API!' }.merge!(hash))
  end

  def welcome_with_headers(hash = {})
    headers hash
    mail
  end

  def welcome_from_another_path(path)
    mail(template_name: 'welcome', template_path: path)
  end

  def welcome_without_deliveries(hash = {})
    mail({ template_name: 'welcome' }.merge!(hash))
    mail.perform_deliveries = false
  end

  def with_name
    to = email_address_with_name('sunny@example.com', 'Sunny')
    mail(template_name: 'welcome', to: to)
  end

  def html_only(hash = {})
    mail(hash)
  end

  def plain_text_only(hash = {})
    mail(hash)
  end

  def inline_attachment
    attachments.inline['logo.png'] = "\312\213\254\232"
    mail
  end

  def inline_and_other_attachments
    attachments.inline['logo.png'] = "\312\213\254\232"
    attachments['certificate.pdf'] = 'This is test File content'
    mail
  end

  def attachment_with_content(hash = {})
    attachments['invoice.pdf'] = 'This is test File content'
    mail(hash)
  end

  def attachment_with_hash
    attachments['invoice.jpg'] = { data: ::Base64.encode64("\312\213\254\232)b"),
                                   mime_type: 'image/x-jpg',
                                   transfer_encoding: 'base64' }
    mail
  end

  def attachment_with_hash_default_encoding
    attachments['invoice.jpg'] = { data: "\312\213\254\232)b",
                                   mime_type: 'image/x-jpg' }
    mail
  end

  def implicit_multipart(hash = {})
    attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
    mail(hash)
  end

  def implicit_multipart_formats(hash = {})
    mail(hash)
  end

  def implicit_with_locale(hash = {})
    mail(hash)
  end

  def explicit_multipart(hash = {})
    attachments['invoice.pdf'] = 'This is test File content' if hash.delete(:attachments)
    mail(hash) do |format|
      format.text { render plain: 'TEXT Explicit Multipart' }
      format.html { render plain: 'HTML Explicit Multipart' }
    end
  end

  def explicit_multipart_templates(hash = {})
    mail(hash) do |format|
      format.html
      format.text
    end
  end

  def explicit_multipart_with_any(hash = {})
    mail(hash) do |format|
      format.any(:text, :html) { render plain: 'Format with any!' }
    end
  end

  def explicit_without_specifying_format_with_any(hash = {})
    mail(hash) do |format|
      format.any
    end
  end

  def explicit_multipart_with_options(include_html = false)
    mail do |format|
      format.text(content_transfer_encoding: 'base64') { render 'welcome' }
      format.html { render 'welcome' } if include_html
    end
  end

  def explicit_multipart_with_one_template(hash = {})
    mail(hash) do |format|
      format.html
      format.text
    end
  end

  def implicit_different_template(template_name = '')
    mail(template_name: template_name)
  end

  def implicit_different_template_with_block(template_name = '')
    mail(template_name: template_name) do |format|
      format.text
      format.html
    end
  end

  def explicit_different_template(template_name = '')
    mail do |format|
      format.text { render template: "#{mailer_name}/#{template_name}" }
      format.html { render template: "#{mailer_name}/#{template_name}" }
    end
  end

  def different_layout(layout_name = '')
    mail do |format|
      format.text { render layout: layout_name }
      format.html { render layout: layout_name }
    end
  end

  def email_with_translations
    mail body: render('email_with_translations', formats: [:html])
  end

  def without_mail_call
  end

  def with_nil_as_return_value
    mail(template_name: 'welcome')
    nil
  end

  def with_subject_interpolations
    mail(subject: default_i18n_subject(rapper_or_impersonator: 'Slim Shady'), body: '')
  end
end
