# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleAuthorize::RSpecMatchers do
  let(:admin) { User.new(id: 1, role: :admin) }
  let(:contributor) { User.new(id: 2, role: :contributor) }
  let(:viewer) { User.new(id: 3, role: :viewer) }
  let(:post) { Post.new(id: 1, user_id: 2) }

  describe "permit_action matcher" do
    context "when action is permitted" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.to permit_action(:destroy) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:show) }
    end

    context "when action is forbidden" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:update) }
    end

    context "with string actions" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.to permit_action("show") }
      it { is_expected.to permit_action("update") }
    end

    context "with explicit expect syntax" do
      it "passes when action is permitted" do
        policy = PostPolicy.new(admin, post)
        expect(policy).to permit_action(:destroy)
      end

      it "fails when action is forbidden" do
        policy = PostPolicy.new(viewer, post)
        expect(policy).not_to permit_action(:destroy)
      end
    end
  end

  describe "forbid_action matcher" do
    context "when action is forbidden" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to forbid_action(:destroy) }
      it { is_expected.to forbid_action(:update) }
    end

    context "when action is permitted" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.not_to forbid_action(:show) }
      it { is_expected.not_to forbid_action(:index) }
    end

    context "with string actions" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to forbid_action("destroy") }
      it { is_expected.to forbid_action("update") }
    end

    context "with explicit expect syntax" do
      it "passes when action is forbidden" do
        policy = PostPolicy.new(viewer, post)
        expect(policy).to forbid_action(:destroy)
      end

      it "fails when action is permitted" do
        policy = PostPolicy.new(admin, post)
        expect(policy).not_to forbid_action(:show)
      end
    end
  end

  describe "permit_viewing matcher" do
    context "when attribute is visible" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to permit_viewing(:title) }
      it { is_expected.to permit_viewing(:body) }
      it { is_expected.to permit_viewing(:id) }
    end

    context "when attribute is hidden" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.not_to permit_viewing(:user_id) }
    end

    context "with string attributes" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.to permit_viewing("title") }
      it { is_expected.to permit_viewing("user_id") }
    end

    context "with explicit expect syntax" do
      it "passes when attribute is visible" do
        policy = PostPolicy.new(viewer, post)
        expect(policy).to permit_viewing(:title)
      end

      it "fails when attribute is hidden" do
        policy = PostPolicy.new(viewer, post)
        expect(policy).not_to permit_viewing(:user_id)
      end
    end
  end

  describe "forbid_viewing matcher" do
    context "when attribute is hidden" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to forbid_viewing(:user_id) }
    end

    context "when attribute is visible" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.not_to forbid_viewing(:title) }
      it { is_expected.not_to forbid_viewing(:user_id) }
    end

    context "with string attributes" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to forbid_viewing("user_id") }
    end

    context "with explicit expect syntax" do
      it "passes when attribute is hidden" do
        policy = PostPolicy.new(viewer, post)
        expect(policy).to forbid_viewing(:user_id)
      end

      it "fails when attribute is visible" do
        policy = PostPolicy.new(admin, post)
        expect(policy).not_to forbid_viewing(:title)
      end
    end
  end

  describe "permit_editing matcher" do
    context "when attribute is editable" do
      subject { PostPolicy.new(contributor, post) }

      it { is_expected.to permit_editing(:title) }
      it { is_expected.to permit_editing(:body) }
    end

    context "when attribute is not editable" do
      subject { PostPolicy.new(contributor, post) }

      it { is_expected.not_to permit_editing(:published) }
    end

    context "with string attributes" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.to permit_editing("title") }
      it { is_expected.to permit_editing("published") }
    end

    context "with explicit expect syntax" do
      it "passes when attribute is editable" do
        policy = PostPolicy.new(contributor, post)
        expect(policy).to permit_editing(:title)
      end

      it "fails when attribute is not editable" do
        policy = PostPolicy.new(contributor, post)
        expect(policy).not_to permit_editing(:published)
      end
    end
  end

  describe "forbid_editing matcher" do
    context "when attribute is not editable" do
      subject { PostPolicy.new(contributor, post) }

      it { is_expected.to forbid_editing(:published) }
    end

    context "when attribute is editable" do
      subject { PostPolicy.new(admin, post) }

      it { is_expected.not_to forbid_editing(:title) }
      it { is_expected.not_to forbid_editing(:published) }
    end

    context "with string attributes" do
      subject { PostPolicy.new(viewer, post) }

      it { is_expected.to forbid_editing("title") }
      it { is_expected.to forbid_editing("published") }
    end

    context "with explicit expect syntax" do
      it "passes when attribute is not editable" do
        policy = PostPolicy.new(contributor, post)
        expect(policy).to forbid_editing(:published)
      end

      it "fails when attribute is editable" do
        policy = PostPolicy.new(admin, post)
        expect(policy).not_to forbid_editing(:title)
      end
    end
  end

  describe "edge cases" do
    context "with nil user" do
      subject { PostPolicy.new(nil, post) }

      it { is_expected.to forbid_action(:update) }
      it { is_expected.to forbid_viewing(:title) }
      it { is_expected.to forbid_editing(:body) }
    end

    context "with missing policy methods" do
      subject { PostPolicy.new(admin, post) }

      it "raises NoMethodError for nonexistent actions" do
        expect { subject.nonexistent_action? }.to raise_error(NoMethodError)
      end
    end
  end
end
