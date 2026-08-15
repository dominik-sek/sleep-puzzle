namespace :content_blocks do
  desc "Create a row for every field declared in config/content_blocks.yml"
  task sync: :environment do
    before = ContentBlock.count
    ContentBlock.sync!
    created = ContentBlock.count - before

    puts created.zero? ? "All #{ContentBlock::Registry.keys.size} content blocks already present." : "Created #{created} content block(s)."

    items_before = ContentItem.count
    ContentItem.sync!
    items_created = ContentItem.count - items_before
    puts items_created.zero? ? "Collections already populated." : "Created #{items_created} collection item(s) from defaults."

    stale = ContentBlock.undeclared.pluck(:key)
    puts "#{stale.size} row(s) no longer declared: #{stale.join(', ')} (remove with content_blocks:prune)" if stale.any?
  end

  desc "Delete rows whose key is no longer declared in config/content_blocks.yml"
  task prune: :environment do
    stale = ContentBlock.undeclared
    count = stale.count

    if count.zero?
      puts "Nothing to prune."
    else
      puts "Deleting #{count} row(s): #{stale.pluck(:key).join(', ')}"
      stale.destroy_all
    end
  end
end
