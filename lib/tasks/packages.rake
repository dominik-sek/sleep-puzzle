namespace :packages do
  desc "Preview the prepared copy; use packages:refresh_copy[apply] to back up and update it"
  task :refresh_copy, [ :mode ] => :environment do |_task, args|
    raise ArgumentError, "Use preview or apply" unless [ nil, "preview", "apply" ].include?(args[:mode])

    refresh = PackageCopyRefresh.new
    refresh.preview.each { |item| puts "#{item[:name]}: #{item[:changed] ? 'do aktualizacji' : 'już zaktualizowany'}" }
    if args[:mode] == "apply"
      backup = refresh.apply!
      puts backup ? "Zapisano treści. Kopia oryginałów: #{backup}" : "Treści już aktualne; bez zmian."
    else
      puts "Podgląd; nie zmieniono danych."
    end
  end
end
