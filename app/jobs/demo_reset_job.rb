# Weekly: clears what App Store and Play reviewers added to the demo community
# and puts the sample content back (CON-66). Does nothing where no demo
# password is configured (development, test).
class DemoResetJob < ApplicationJob
  queue_as :default

  def perform
    password = ENV["DEMO_USER_PASSWORD"]
    return if password.blank?

    DemoCommunity.new(password: password).reset!
  end
end
