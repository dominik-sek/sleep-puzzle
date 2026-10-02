class PurgeStagedMediaUploadsJob < ApplicationJob
  queue_as :default

  def perform
    StagedMediaUpload.where(created_at: ..2.days.ago).find_each(&:cleanup!)
  end
end
