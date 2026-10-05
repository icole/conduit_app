# frozen_string_literal: true

class PagesController < ApplicationController
  # Public, static pages (privacy, terms) that any visitor and the app stores
  # must reach, on any host, signed in or not
  skip_before_action :set_tenant_from_domain
  skip_before_action :authenticate_user!
  skip_before_action :verify_user_belongs_to_tenant!

  def privacy
  end

  def terms
  end
end
