require "test_helper"

class MailingListTest < ActiveSupport::TestCase
  def setup
    # Stub MailgunService to prevent actual API calls
    @mailgun_service_stub = Object.new
    def @mailgun_service_stub.create_mailing_list(name, *args); "#{name}@lists.example.com"; end
    def @mailgun_service_stub.update_mailing_list(*args); true; end
    def @mailgun_service_stub.delete_mailing_list(*args); true; end
    def @mailgun_service_stub.add_member(*args); true; end
    def @mailgun_service_stub.remove_member(*args); true; end

    @mailing_list = MailingList.new(
      name: "test-community-#{Time.current.to_i}",
      description: "Community announcements and updates"
    )
  end

  test "should be valid with valid attributes" do
    assert @mailing_list.valid?
  end

  test "should require name" do
    @mailing_list.name = nil
    assert_not @mailing_list.valid?
    assert_includes @mailing_list.errors[:name], "can't be blank"
  end

  test "should require description" do
    @mailing_list.description = nil
    assert_not @mailing_list.valid?
    assert_includes @mailing_list.errors[:description], "can't be blank"
  end

  test "should require unique name" do
    MailgunService.stub :new, @mailgun_service_stub do
      @mailing_list.save!
      duplicate = MailingList.new(name: @mailing_list.name, description: "Another list")
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
    end
  end

  test "name should only allow valid characters" do
    invalid_names = [ "Community", "comm unity", "comm@unity", "comm.unity" ]
    invalid_names.each do |invalid_name|
      @mailing_list.name = invalid_name
      assert_not @mailing_list.valid?, "#{invalid_name} should be invalid"
    end

    valid_names = [ "team-updates", "dev_team", "announcements123" ]
    valid_names.each do |valid_name|
      @mailing_list.name = "#{valid_name}-#{Time.current.to_i}"
      assert @mailing_list.valid?, "#{valid_name} should be valid"
    end
  end

  test "should default active to true" do
    @mailing_list.save!
    assert @mailing_list.active?
  end

  test "email_address should generate correct subdomain format" do
    @mailing_list.name = "test-list"

    # Test with environment variables
    original_domain = ENV["MAILING_LIST_DOMAIN"]
    original_subdomain = ENV["MAILING_LIST_SUBDOMAIN"]
    ENV["MAILING_LIST_DOMAIN"] = "example.com"
    ENV["MAILING_LIST_SUBDOMAIN"] = "lists"

    assert_equal "test-list@lists.example.com", @mailing_list.email_address

    # Test with default subdomain
    ENV["MAILING_LIST_SUBDOMAIN"] = nil
    # Need to reload the model to clear any memoization
    @mailing_list = MailingList.find(@mailing_list.id) if @mailing_list.persisted?
    assert_equal "test-list@lists.example.com", @mailing_list.email_address

    # Restore original environment
    ENV["MAILING_LIST_DOMAIN"] = original_domain
    ENV["MAILING_LIST_SUBDOMAIN"] = original_subdomain
  end

  test "should count members correctly" do
    MailgunService.stub :new, @mailgun_service_stub do
      @mailing_list.save!
      user = User.create!(name: "Test User", email: "test@example.com", password: "password123")

      assert_equal 0, @mailing_list.member_count

      @mailing_list.add_user(user)
      assert_equal 1, @mailing_list.member_count
    end
  end

  test "should add and remove users" do
    MailgunService.stub :new, @mailgun_service_stub do
      @mailing_list.save!
      user = User.create!(name: "Test User", email: "test@example.com", password: "password123")

      @mailing_list.add_user(user)
      assert @mailing_list.member?(user)
      assert_includes @mailing_list.users, user

      @mailing_list.remove_user(user)
      assert_not @mailing_list.member?(user)
      assert_not_includes @mailing_list.users, user
    end
  end

  test "should not add duplicate users" do
    MailgunService.stub :new, @mailgun_service_stub do
      @mailing_list.save!
      user = User.create!(name: "Test User", email: "test@example.com", password: "password123")

      @mailing_list.add_user(user)
      @mailing_list.add_user(user)

      assert_equal 1, @mailing_list.member_count
    end
  end
end
