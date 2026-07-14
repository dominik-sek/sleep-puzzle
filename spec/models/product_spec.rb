require 'rails_helper'

# == Schema Information
#
# Table name: products
#
#  id          :bigint           not null, primary key
#  category    :integer
#  description :text
#  kind        :integer
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
RSpec.describe Product, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
