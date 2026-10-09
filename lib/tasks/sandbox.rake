namespace :sandbox do
  desc "Preview one user's test purchases; delete only with CONFIRM from the preview"
  task cleanup_user: :environment do
    cleanup = SandboxPurchaseCleanup.new(email: ENV["EMAIL"])
    if ENV["CONFIRM"].present?
      counts = cleanup.purge!(confirmation: ENV["CONFIRM"])
      puts "Usunięto testowe zakupy i konsultacje. Konto użytkownika pozostało."
      puts JSON.pretty_generate(counts)
    else
      puts "PODGLĄD — nic nie zostało usunięte. Wszystkie zakupy tego konta muszą być testami."
      puts JSON.pretty_generate(cleanup.preview)
      puts "Po wykonaniu kopii bazy użyj tego samego EMAIL i CONFIRM z pola confirmation."
    end
  rescue SandboxPurchaseCleanup::UnsafeCleanup, ActiveRecord::RecordNotFound => e
    abort e.message
  end
end
