require 'rails_helper'
require 'pull_request_status'
require 'feature_review_with_statuses'

RSpec.describe PullRequestStatus do
  subject(:pull_request_status) { described_class.new(token: token) }

  let(:token) { 'a-token' }
  let(:routes) { double(:routes) }

  let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
  let(:sha) { 'abc123' }
  let(:repo_url) { 'ssh://github.com/some/repo.git' }
  let(:expected_url) { 'https://api.github.com/repos/some/repo/statuses/abc123' }

  let(:expected_headers) {
    {
      'Accept' => 'application/vnd.github.v3+json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => 'token a-token',
      'Content-Type' => 'application/json',
      'User-Agent' => 'Octokit Ruby Gem 4.1.0',
    }
  }

  before do
    allow(Repositories::TicketRepository).to receive(:new).and_return(ticket_repository)
    allow(ticket_repository).to receive(:tickets_for_versions).and_return([])
  end

  describe '#update' do
    context 'when a single feature review exists' do
      let(:ticket) {
        Ticket.new(
          versions: %w(abc123 xyz),
          paths: [feature_review_path(app1: 'abc123', app2: 'xyz')],
          status: 'Done',
          approved_at: Time.current,
        )
      }
      let(:root_url) { 'https://shipment-tracker.co.uk/' }

      before do
        allow(ticket_repository).to receive(:tickets_for_versions).with([sha]).and_return([ticket])
      end

      it 'posts status "success" with description and link to feature review' do
        expected_body = {
          context: 'shipment-tracker',
          target_url: 'https://localhost/feature_reviews?apps%5Bapp1%5D=abc123&apps%5Bapp2%5D=xyz',
          description: 'Approved Feature Review found',
          state: 'success',
        }
        stub = stub_request(:post, expected_url).with(body: expected_body, headers: expected_headers)

        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end

      context 'when the ticket references multiple feature reviews, but only one is for the commit' do
        let(:ticket) {
          Ticket.new(
            versions: %w(abc123 def456 uvw),
            paths: [
              feature_review_path(app1: 'abc123', app2: 'xyz'),
              feature_review_path(app1: 'def456'),
            ],
            status: 'Done',
            approved_at: Time.current,
          )
        }
        it 'posts status "success" with description and link to feature review' do
          expected_body = {
            context: 'shipment-tracker',
            target_url: 'https://localhost/feature_reviews?apps%5Bapp1%5D=abc123&apps%5Bapp2%5D=xyz',
            description: 'Approved Feature Review found',
            state: 'success',
          }
          stub = stub_request(:post, expected_url).with(body: expected_body)

          pull_request_status.update(repo_url: repo_url, sha: sha)
          expect(stub).to have_been_requested
        end
      end
    end

    context 'when multiple feature reviews exist for the same commit' do
      context 'when any feature reviews are approved' do
        let(:approved_ticket) {
          Ticket.new(
            versions: %w(abc123 uvw),
            paths: [
              feature_review_path(app1: 'abc123', app2: 'uvw'),
              feature_review_path(app1: 'abc123'),
            ],
            status: 'Done',
            approved_at: Time.current,
          )
        }
        let(:unapproved_ticket) {
          Ticket.new(
            versions: %w(abc123 uvw),
            paths: [feature_review_path(app1: 'abc123', app2: 'uvw')],
            status: 'In Progress',
            approved_at: nil,
          )
        }

        let(:search_url) { 'https://localhost/feature_reviews/search?application=repo&version=abc123' }

        before do
          allow(ticket_repository)
            .to receive(:tickets_for_versions).with([sha]).and_return([approved_ticket, unapproved_ticket])
        end

        it 'posts status "success" with description and to feature review search' do
          expected_body = {
            context: 'shipment-tracker',
            target_url: search_url,
            description: 'Approved Feature Review found',
            state: 'success',
          }
          stub = stub_request(:post, expected_url).with(body: expected_body)

          pull_request_status.update(repo_url: repo_url, sha: sha)
          expect(stub).to have_been_requested
        end
      end

      context 'when no feature reviews are approved' do
        let(:approved_ticket) {
          Ticket.new(
            versions: %w(abc123 uvw),
            paths: [
              feature_review_path(app1: 'abc123', app2: 'uvw'),
              feature_review_path(app1: 'abc123'),
            ],
            status: 'In Progress',
            approved_at: Time.current,
          )
        }
        let(:unapproved_ticket) {
          Ticket.new(
            versions: %w(abc123 uvw),
            paths: [feature_review_path(app1: 'abc123', app2: 'uvw')],
            status: 'Done',
            approved_at: nil,
          )
        }

        let(:search_url) { 'https://localhost/feature_reviews/search?application=repo&version=abc123' }

        before do
          allow(ticket_repository)
            .to receive(:tickets_for_versions).with([sha]).and_return([approved_ticket, unapproved_ticket])
        end

        it 'posts status "pending" with description and link to feature review search' do
          expected_body = {
            context: 'shipment-tracker',
            target_url: search_url,
            description: 'Awaiting approval for Feature Review',
            state: 'pending',
          }
          stub = stub_request(:post, expected_url).with(body: expected_body)

          pull_request_status.update(repo_url: repo_url, sha: sha)
          expect(stub).to have_been_requested
        end
      end
    end

    context 'when no feature review exists' do
      let(:feature_review_url) { 'https://localhost/feature_reviews?apps%5Brepo%5D=abc123' }

      before do
        allow(ticket_repository).to receive(:tickets_for_versions).with([sha]).and_return([])
      end

      it 'posts status "failure" with description and link to view a feature review' do
        expected_body = {
          context: 'shipment-tracker',
          target_url: feature_review_url,
          description: "No Feature Review found. Click 'Details' to create one.",
          state: 'failure',
        }
        stub = stub_request(:post, expected_url).with(body: expected_body)

        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end
    end
  end

  describe '#reset' do
    let(:html_url) { 'http://github.com/some/repo' }

    it 'posts status "pending" with description and no link' do
      expected_body = {
        context: 'shipment-tracker',
        target_url: nil,
        description: 'Searching for Feature Review',
        state: 'pending',
      }
      stub = stub_request(:post, expected_url).with(body: expected_body, headers: expected_headers)

      pull_request_status.reset(repo_url: html_url, sha: sha)
      expect(stub).to have_been_requested
    end
  end
end
