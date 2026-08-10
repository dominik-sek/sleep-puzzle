require 'rails_helper'

# == Schema Information
#
# Table name: packages
#
#  id              :bigint           not null, primary key
#  core            :jsonb
#  duration        :integer
#  extra           :jsonb
#  for_whom        :text
#  name            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  paddle_price_id :string
#
# Indexes
#
#  index_packages_on_core   (core) USING gin
#  index_packages_on_extra  (extra) USING gin
#
RSpec.describe Package, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
