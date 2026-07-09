# == Schema Information
#
# Table name: packages
#
#  id         :bigint           not null, primary key
#  core       :jsonb
#  duration   :integer
#  extra      :jsonb
#  for_whom   :text
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_packages_on_core   (core) USING gin
#  index_packages_on_extra  (extra) USING gin
#
class Package < ApplicationRecord
end
