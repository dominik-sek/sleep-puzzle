class AddAudioProcessChaptersAndTrailers < ActiveRecord::Migration[8.1]
  def up
    create_table :audio_chapters do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.jsonb :translations, null: false, default: {}
      t.string :cdn_path
      t.integer :duration_seconds
      t.string :upload_error
      t.timestamps
    end
    add_index :audio_chapters, [ :product_id, :position, :id ]

    add_column :products, :trailer_cdn_path, :string
    add_column :products, :trailer_upload_error, :string

    create_table :staged_media_uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.string :filename, null: false
      t.bigint :byte_size, null: false
      t.integer :chunk_count, null: false
      t.string :token, null: false
      t.datetime :completed_at
      t.timestamps
    end
    add_index :staged_media_uploads, :token, unique: true
    add_index :staged_media_uploads, [ :target_type, :target_id ]

    backfill_legacy_audio
  end

  def backfill_legacy_audio
    execute <<~SQL
      INSERT INTO audio_chapters (product_id, position, translations, cdn_path, duration_seconds, created_at, updated_at)
      SELECT id, 0,
             jsonb_build_object('title', jsonb_build_object('pl', 'Nagranie', 'en', 'Recording')),
             cdn_path, length_minutes * 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM products
      WHERE kind = 0 AND cdn_path IS NOT NULL AND cdn_path <> ''
    SQL
  end

  def down
    drop_table :staged_media_uploads
    remove_column :products, :trailer_upload_error
    remove_column :products, :trailer_cdn_path
    drop_table :audio_chapters
  end
end
