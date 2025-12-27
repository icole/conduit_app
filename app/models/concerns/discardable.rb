# frozen_string_literal: true

module Discardable
  extend ActiveSupport::Concern

  included do
    include Discard::Model

    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :deleted_by, class_name: "User", optional: true

    default_scope -> { kept }

    # Set deleted_by before discarding
    before_discard :set_deleted_by

    # Scope for admin/audit purposes
    scope :only_discarded, -> { with_discarded.discarded }
  end

  # Aliases for convenience
  def soft_delete = discard
  def soft_deleted? = discarded?
  def restore = undiscard

  private

  def set_deleted_by
    self.deleted_by = Current.user if respond_to?(:deleted_by=)
  end

  class_methods do
    # Cascade soft delete to specified associations
    # Usage: cascade_discard :comments, :likes
    def cascade_discard(*associations)
      after_discard do
        associations.each do |assoc|
          send(assoc).find_each(&:discard)
        end
      end

      after_undiscard do
        associations.each do |assoc|
          send(assoc).with_discarded.discarded.find_each(&:undiscard)
        end
      end
    end
  end
end
