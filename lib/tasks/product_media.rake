namespace :products do
  desc "Prepare a poster and duration for an existing trailer: products:trailer_poster[ID,SOURCE_FILE] (source defaults to CDN)"
  task :trailer_poster, [ :id, :source ] => :environment do |_task, args|
    product = Product.audio_process.find(args.fetch(:id))
    abort "This product has no trailer path." if product.trailer_cdn_path.blank?
    path = product.trailer_cdn_path
    if args[:source].present?
      abort "Provide the original trailer file as SOURCE_FILE." unless File.file?(args[:source])
      source = args[:source]
    else
      source = BunnySignedUrlService.call(path)
      abort "Bunny CDN is not configured." unless source
    end

    poster = TrailerPosterService.call(source)
    abort "Could not prepare a poster from this file." unless poster
    begin
      duration = MediaDurationService.call(source)
      product.with_lock do
        abort "The trailer changed; run this task again." unless product.trailer_cdn_path == path

        product.trailer_poster.attach(io: poster, filename: "trailer-poster.jpg", content_type: "image/jpeg",
                                     metadata: { trailer_cdn_path: path, duration_seconds: duration })
      end
      puts "Poster prepared for product #{product.id} (duration: #{duration || 'unknown'} seconds)."
    ensure
      poster.close!
    end
  end
end
