require "test_helper"
require "accessly/policy/base_option_3"

describe Accessly::Policy::BaseOption3 do
############
# NOTE TO SELF
# BaseOption3 implements an API like this:
# UserPolicy.new(user).can?(view)
# UserPolicy.new(user).can?(:view, other_user)
# UserPolicy.new(user).list(:view)
#
# BaseOption2 implements it the same way.
# However BaseOption3 allows us to more easily override
# permission checks than BaseOption2.
#
# We will need to decide which one to move forward with.
############

  class UserPolicyOption3 < Accessly::Policy::BaseOption3

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

  class CustomizedPolicyOption3 < UserPolicyOption3
    # Customize a general action check
    override_action_check :destroy, ->(actor) { true if actor.name == "Aaron" }

    # Customize a check that is both general and on an object
    override_action_check :change_role, ->(actor) do
      false if actor.name == "Bob"
    end
    override_object_action_check :change_role, ->(actor, object) do
      true if object.name == "Aaron"
    end

    # Customize an object action check
    override_object_action_check :email, ->(actor, object) { true if object.name == "Aaron" }
  end

  class PolicyWithoutObjectTypeOption3 < Accessly::Policy::BaseOption3
    actions view: 1
  end

  it "defines action lookup methods" do
    user = User.create!
    other_user = User.create!

    UserPolicyOption3.new(user).can?(:view)
    UserPolicyOption3.new(user).can?(:edit_basic_info)
    UserPolicyOption3.new(user).can?(:change_role)
    UserPolicyOption3.new(user).can?(:destroy)

    UserPolicyOption3.new(user).can?(:view, other_user)
    UserPolicyOption3.new(user).can?(:edit_basic_info, other_user)
    UserPolicyOption3.new(user).can?(:change_role, other_user)
    UserPolicyOption3.new(user).can?(:email, other_user)
  end

  it "limits lookup methods to contexts with and without objects appropriately" do
    user = User.create!
    other_user = User.create!

    assert_raises(ArgumentError) do
      UserPolicyOption3.new(user).can?(:email)
    end

    assert_raises(ArgumentError) do
      UserPolicyOption3.new(user).can?(:destroy, other_user)
    end
  end

  it "requires object_type to be defined" do
    assert_raises(NotImplementedError) do
      PolicyWithoutObjectTypeOption3.new(User.new).can?(:view)
    end
  end

  it "looks up non-object permissions from the Accessly library" do
    user = User.create!

    UserPolicyOption3.new(user).can?(:edit_basic_info).must_equal false

    Accessly::PermittedAction.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 2,
      object_type: String(User)
    )

    UserPolicyOption3.new(user).can?(:edit_basic_info).must_equal true
  end

  it "caches non-object permission lookups" do
    user = User.create!
    policy = UserPolicyOption3.new(user)

    policy.can?(:edit_basic_info).must_equal false

    permission = Accessly::PermittedAction.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 2,
      object_type: String(User)
    )

    policy.can?(:edit_basic_info).must_equal false

    policy = UserPolicyOption3.new(user)
    policy.can?(:edit_basic_info).must_equal true
    permission.destroy!
    policy.can?(:edit_basic_info).must_equal true
  end

  it "looks up object permissions from the Accessly library" do
    user = User.create!
    other_user = User.create!

    UserPolicyOption3.new(user).can?(:email, other_user).must_equal false

    Accessly::PermittedActionOnObject.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 4,
      object: other_user
    )

    UserPolicyOption3.new(user).can?(:email, other_user).must_equal true
  end

  it "caches object permission lookups" do
    user = User.create!
    other_user = User.create!
    policy = UserPolicyOption3.new(user)

    policy.can?(:email, other_user).must_equal false

    permission = Accessly::PermittedActionOnObject.create!(
      id: SecureRandom.uuid,
      segment_id: -1,
      actor: user,
      action: 4,
      object: other_user
    )

    policy.can?(:email, other_user).must_equal false

    policy = UserPolicyOption3.new(user)
    policy.can?(:email, other_user).must_equal true
    permission.destroy!
    policy.can?(:email, other_user).must_equal true
  end

  it "allows general action checks to be customized" do
    # User named Aaron can always destroy users
    user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption3.new(user)
    policy.can?(:destroy).must_equal true

    # User not named Aaron gets normal privileges
    user = User.create!(name: "Jim")
    policy = CustomizedPolicyOption3.new(user)
    policy.can?(:destroy).must_equal false
  end

  it "allows object action checks to be customized" do
    # Anybody can email user named Aaron
    user = User.create!
    other_user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption3.new(user)
    policy.can?(:email, other_user).must_equal true

    # Emailing other users goes through normal privilege check
    policy.can?(:email, user).must_equal false
  end

  it "allows checks that are both general and on an object to be customized" do
    # User named Bob cannot generally change role
    user = User.create!(name: "Bob")
    other_user = User.create!(name: "Aaron")
    policy = CustomizedPolicyOption3.new(user)
    policy.can?(:change_role).must_equal false

    # User named Bob can change role for specific user named Aaron
    policy.can?(:change_role, other_user).must_equal true

    # User named Aaron has normal privileges
    policy = CustomizedPolicyOption3.new(other_user)
    policy.can?(:change_role).must_equal false
    policy.can?(:change_role, user).must_equal false
  end
end
