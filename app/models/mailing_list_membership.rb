class MailingListMembership < ApplicationRecord
  belongs_to :mailing_list
  belongs_to :user

  validates :mailing_list_id, uniqueness: { scope: :user_id, message: "User is already a member of this mailing list" }
end
