# frozen_string_literal: true

module PaymentsHelper
  STATUS_CLASSES = {
    'requires_payment_method' => 'bg-secondary',
    'requires_confirmation' => 'bg-warning',
    'requires_action' => 'bg-danger',
    'processing' => 'bg-info',
    'succeeded' => 'bg-success'
  }.freeze

  def payment_status(status)
    css_class = STATUS_CLASSES.fetch(status, 'bg-light text-dark')
    label = I18n.t("payments.status.#{status}", default: I18n.t('payments.status.unknown'))

    safe_join([
                content_tag(:span, nil, class: "badge #{css_class} me-1"),
                label
              ])
  end
end
