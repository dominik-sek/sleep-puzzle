# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Content blocks are declared in ContentBlock::BLOCKS; this creates any that are
# missing without touching copy that already exists. Also available on its own as
# `bin/rails content_blocks:sync`, for running after a deploy that adds a block.
ContentBlock.sync!
ContentItem.sync!
