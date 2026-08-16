# Preview contact mail at http://localhost:3000/rails/mailers/contact_mailer
class ContactMailerPreview < ActionMailer::Preview
  def new_message
    ContactMailer.with(message: example_message).new_message
  end

  private

  def example_message
    ContactMessage.new(
      name: "Jan Kowalski",
      email: "jan@example.com",
      body: "Dzień dobry,\n\nmoja córka ma 8 miesięcy i budzi się co godzinę. Czy taki pakiet ma sens w naszej sytuacji?\n\nPozdrawiam"
    )
  end
end
