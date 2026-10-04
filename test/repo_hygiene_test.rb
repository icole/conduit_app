require "test_helper"

# This repo is public, so a credential committed here is disclosed the moment it
# is pushed. Apple .p8 auth keys are the sharpest case: they are one-time
# downloads with no passphrase and no expiry, so a leaked one can only be
# revoked, never rotated quietly. Keys do get parked in a working copy while
# configuring signing, so ignore them by pattern rather than trusting everyone
# to remember.
class RepoHygieneTest < ActiveSupport::TestCase
  test "apple .p8 auth keys are ignored by git anywhere in the tree" do
    %w[
      AuthKey_ABC123.p8
      config/AuthKey_ABC123.p8
      ios/Conduit_AuthKey_ABC123.p8
    ].each do |path|
      assert git_ignores?(path),
        "#{path} is not gitignored; an Apple private key dropped there could be committed to a public repo"
    end
  end

  test "no .p8 file is currently tracked by git" do
    tracked = `git -C #{Rails.root} ls-files -z -- '*.p8'`.split("\x0")

    assert_empty tracked, "Apple auth keys are tracked by git: #{tracked.join(', ')}"
  end

  private

  # git check-ignore exits 0 when the path would be ignored, 1 when it would not.
  def git_ignores?(path)
    system("git", "-C", Rails.root.to_s, "check-ignore", "--quiet", path)
  end
end
