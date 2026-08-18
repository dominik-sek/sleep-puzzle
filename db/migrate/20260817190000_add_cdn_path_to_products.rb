class AddCdnPathToProducts < ActiveRecord::Migration[8.1]
  def change
    # Where the file sits inside the Bunny storage zone ("/bajki/o-sowie.mp3"),
    # not a full URL: the hostname is one pull zone for the whole catalogue and
    # lives in BUNNY_CDN_HOST, and the URL a buyer actually gets is signed per
    # play, so storing one here would store a link that expires.
    #
    # Nullable on purpose. A product whose audio has not been uploaded yet is a
    # perfectly good shop listing; it just has no player (see Product#streamable?).
    add_column :products, :cdn_path, :string
  end
end
