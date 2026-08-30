# Why the last background upload did not land, in the admin's language. Nil while
# nothing has failed, which is also how the form tells a pending upload from a
# failed one — the staged attachment is gone either way once the job is done.
class AddAudioUploadErrorToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :audio_upload_error, :string
  end
end
