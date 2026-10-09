namespace :sandbox do
  desc "Preview one user's test purchases; delete only with CONFIRM from the preview"
  task cleanup_user: :environment do
    cleanup = SandboxPurchaseCleanup.new(email: ENV["EMAIL"], skip_google_calendar: ENV["SKIP_GOOGLE_CALENDAR"] == "1")
    preview = cleanup.preview
    if preview[:skip_google_calendar]
      puts "Pomijam Google Calendar. Wydarzenia pozostaną w Google; zachowaj poniższą listę do ręcznego usunięcia."
      puts JSON.pretty_generate(calendar_events: preview[:calendar_events])
    end
    if ENV["CONFIRM"].present?
      counts = cleanup.purge!(confirmation: ENV["CONFIRM"])
      puts "Usunięto testowe zakupy i konsultacje. Konto użytkownika pozostało."
      puts JSON.pretty_generate(counts)
    else
      puts "PODGLĄD — nic nie zostało usunięte. Wszystkie zakupy tego konta muszą być testami."
      puts JSON.pretty_generate(preview)
      puts "Po wykonaniu kopii bazy użyj tego samego EMAIL i CONFIRM z pola confirmation."
    end
  rescue SandboxPurchaseCleanup::UnsafeCleanup, ActiveRecord::RecordNotFound => e
    abort e.message
  rescue GoogleCalendarService::NotConnected
    abort "Google Calendar jest odłączony. Dane w bazie nie zostały usunięte. Aby pominąć wydarzenia Google, wykonaj nowy podgląd z SKIP_GOOGLE_CALENDAR=1, a następnie użyj nowego CONFIRM i tej samej opcji."
  end
end
