namespace :products do
  desc "Prepare a local poster for an existing trailer: products:trailer_poster[ID,SOURCE_FILE]"
  task :trailer_poster, [ :id, :source ] => :environment do |_task, args|
    product = Product.audio_process.find(args.fetch(:id))
    abort "Provide the original trailer file as SOURCE_FILE." unless File.file?(args[:source].to_s)
    abort "This product has no trailer path." if product.trailer_cdn_path.blank?

    poster = TrailerPosterService.call(args[:source])
    abort "Could not prepare a poster from this file." unless poster
    begin
      product.trailer_poster.attach(io: poster, filename: "trailer-poster.jpg", content_type: "image/jpeg",
                                   metadata: { trailer_cdn_path: product.trailer_cdn_path })
      puts "Poster prepared for product #{product.id}."
    ensure
      poster.close!
    end
  end
end
