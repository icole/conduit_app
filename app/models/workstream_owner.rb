class WorkstreamOwner < ApplicationRecord
  acts_as_tenant :community

  belongs_to :workstream
  belongs_to :user

  validates :user_id, uniqueness: { scope: :workstream_id }
end
