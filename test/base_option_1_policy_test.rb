require "test_helper"
require "accessly/policy/base_option_1"

describe Accessly::Policy::BaseOption1 do
############
# BaseOption1 implements an API like this:
# UserPolicy.new(user).view?
# UserPolicy.new(user).view?(other_user)
# UserPolicy.new(user).view_list
#
# BaseOption2 implements a slightly different way.
#
# We will need to decide which one to move forward with.
############

  class UserPolicyOption1 < Accessly::Policy::BaseOption1

    actions(
      view: 1,
      edit_basic_info: 2,
      change_role: 3,
      destroy: 4
    )

    actions_on_objects(
      view: 1,
      edit_basic_info: 2,
      change_role: 3,
      email: 4
    )

    def self.object_type
      User
    end
  end

  class CustomizedPolicyOption1 < UserPolicyOption1
    # Customize a general action check
    def destroy?
      if actor.name == "Aaron"
        true
      else
        super
      end
    end

    # Customize a check that is both general and on an object
    def change_role?(object = nil)
      if object.nil?
        if actor.name == "Bob"
          false
        else
          super
        end
      elsif actor.name == "Bob" && object.name == "Aaron"
        true
      else
        super
      end
    end

    # Customize an object action check
    def email?(object)
      if object.name == "Aaron"
        true
      else
        super
      end
    end
  end

  class PolicyWithoutObjectTypeOption1 < Accessly::Policy::BaseOption1
    actions view: 1
  end

  it "defines action lookup methods" do
    user = User.create!
    other_user = User.create!

    UserPolicyOption1.new(user).view?
    UserPolicyOption1.new(user).edit_basic_info?
    UserPolicyOption1.new(user).change_role?
    UserPolicyOption1.new(user).destroy?

    UserPolicyOption1.new(user).view?(other_user)
    UserPolicyOption1.new(user).edit_basic_info?(other_user)
    UserPolicyOption1.new(user).change_role?(other_user)
    UserPolicyOption1.new(user).email?(other_user)
  end

  it "limits lookup methods to contexts with and without objects appropriately" do
    user = User.create!
    other_user = User.create!

    assert_raises(ArgumentError) do
      UserPolicyOption1.new(user).email?
    end

    assert_raises(ArgumentError) do
      UserPolicyOption1.new(user).destroy?(other_user)
    end
  end

  it "requires object_type to be defined" do
    assert_raises(NotImplementedError) do
      PolicyWithoutObjectTypeOption1.new(User.new).view?
    end
  end

  it "looks up non-object permissions from the Accessly library" do
    user = User.create!

    UserPolicyOption1.new(user).edit_basic_info?.must_equal false

    Accessly::PermittedAction.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 2,
      object_type: String(User)
    )

    UserPolicyOption1.new(user).edit_basic_info?.must_equal true
  end

  it "caches non-object permission lookups" do
    user = User.create!
    policy = UserPolicyOption1.new(user)

    policy.edit_basic_info?.must_equal false

    permission = Accessly::PermittedAction.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 2,
      object_type: String(User)
    )

    policy.edit_basic_info?.must_equal false

    policy = UserPolicyOption1.new(user)
    policy.edit_basic_info?.must_equal true
    permission.destroy!
    policy.edit_basic_info?.must_equal true
  end

  it "looks up object permissions from the Accessly library" do
    user = User.create!
    other_user = User.create!

    UserPolicyOption1.new(user).email?(other_user).must_equal false

    Accessly::PermittedActionOnObject.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 4,
      object: other_user
    )

    UserPolicyOption1.new(user).email?(other_user).must_equal true
  end

  it "caches object permission lookups" do
    user = User.create!
    other_user = User.create!
    policy = UserPolicyOption1.new(user)

    policy.email?(other_user).must_equal false

    permission = Accessly::PermittedActionOnObject.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 4,
      object: other_user
    )

    policy.email?(other_user).must_equal false

    policy = UserPolicyOption1.new(user)
    policy.email?(other_user).must_equal true
    permission.destroy!
    policy.email?(other_user).must_equal true
  end

  it "allows general action checks to be customized" do
    # User named Aaron can always destroy users
    user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption1.new(user)
    policy.destroy?.must_equal true

    # User not named Aaron gets normal privileges
    user = User.create!(name: "Jim")
    policy = CustomizedPolicyOption1.new(user)
    policy.destroy?.must_equal false
  end

  it "allows object action checks to be customized" do
    # Anybody can email user named Aaron
    user = User.create!
    other_user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption1.new(user)
    policy.email?(other_user).must_equal true

    # Emailing other users goes through normal privilege check
    policy.email?(user).must_equal false
  end

  it "allows checks that are both general and on an object to be customized" do
    # User named Bob cannot generally change role
    user = User.create!(name: "Bob")
    other_user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption1.new(user)
    policy.change_role?.must_equal false

    # User named Bob can change role for specific user named Aaron
    policy.change_role?(other_user).must_equal true

    # User named Aaron has normal privileges
    policy = CustomizedPolicyOption1.new(other_user)
    policy.change_role?.must_equal false
    policy.change_role?(user).must_equal false
  end
end
