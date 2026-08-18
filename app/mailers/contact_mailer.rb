class ContactMailer < ApplicationMailer
  # to the owner, when someone writes from the contact page
  def new_message
    # rebuilt from the attributes the controller enqueued: ContactMessage is not
    # a record, so there is no global id for Active Job to pass instead
    @message = ContactMessage.new(params.slice(:name, :email, :body))

    # replies go to the sender, so answering the notification reaches them
    # directly — the same arrangement as BookingMailer#new_booking
    mail to: ENV.fetch("OWNER_EMAIL"),
         reply_to: @message.email,
         subject: t("contact_mailer.new_message.subject", name: @message.name)
  end
end
