class PurchaseConfirmationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(kind, id)
    record = (kind == "order" ? Order : Booking).find_by(id: id)
    return unless record

    record.with_lock do
      return if record.legal_snapshot.blank? || record.legal_confirmation_sent_at?

      I18n.with_locale(record.legal_snapshot.fetch("locale")) do
        PurchaseMailer.with(record: record).confirmed.deliver_now
      end
      record.update!(legal_confirmation_sent_at: Time.current)
    end
  end
end
