# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe SamsonGitlab do
  it 'configures GitLab API client' do
    Gitlab.endpoint.must_equal "#{Rails.application.config.samson.gitlab.web_url}/api/v4"
    Gitlab.private_token.must_equal ENV['GITLAB_TOKEN']
  end

  describe :changeset_api_request do
    let(:project) { Project.new(repository_url: 'ssh://git@gitlab.com:foo/bar.git') }
    let(:changeset) { Changeset.new(project, "a", "b") }
    let(:api_request) { ->(path) { "https://gitlab.com/api/v4/projects/foo%2Fbar/repository/" + path } }

    def fire(method)
      Samson::Hooks.fire(:changeset_api_request, changeset, method)
    end

    around { |t| Samson::Hooks.only_callbacks_for_plugin('gitlab', :changeset_api_request, &t) }

    it "calls branch api endpoint" do
      stub_request(:get, api_request["branches/b"]).to_return(body: JSON.dump(commit: {id: 'foo'}))
      fire(:branch).must_equal ["foo"]
    end

    it "calls compare api endpoint" do
      stub_request(:get, api_request["compare?from=a&to=b"]).to_return(body: JSON.dump(diffs: [], commits: []))
      fire(:compare).first.to_h.must_equal(files: [], commits: [])
    end

    it "requires a valid method" do
      assert_raises(NoMethodError) { fire(:bad) }
    end

    it "catches exception and returns NullComparison" do
      stub_request(:get, api_request["compare?from=a&to=b"]).to_return(status: 401)
      fire(:compare).first.class.must_equal(Changeset::NullComparison)
    end
  end
end
