# frozen_string_literal: true

class CachingMailer < ActionMailer::Base
  self.mailer_name = 'caching_mailer'

  def fragment_cache
    mail(subject: 'welcome', template_name: 'fragment_cache')
  end

  def fragment_cache_in_partials
    mail(subject: 'welcome', template_name: 'fragment_cache_in_partials')
  end

  def skip_fragment_cache_digesting
    mail(subject: 'welcome', template_name: 'skip_fragment_cache_digesting')
  end

  def fragment_caching_options
    mail(subject: 'welcome', template_name: 'fragment_caching_options')
  end

  def multipart_cache
    mail(subject: 'welcome', template_name: 'multipart_cache')
  end
end
