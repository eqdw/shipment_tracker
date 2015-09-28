class ReleasesController < ApplicationController
  def index
    @app_names = GitRepositoryLocation.app_names
  end

  def show
    projection = build_projection
    @pending_releases = projection.pending_releases
    @deployed_releases = projection.deployed_releases
    @app_name = app_name
  rescue GitRepositoryLoader::NotFound
    render text: 'Repository not found', status: :not_found
  end

  private

  def build_projection
    Queries::ReleasesQuery.new(
      per_page: 50,
      git_repo: git_repository,
      deploy_repo: deploy_repository,
      feature_review_repo: feature_review_repository,
      app_name: app_name)
  end

  def app_name
    params[:id]
  end

  def deploy_repository
    Repositories::DeployRepository.new
  end

  def feature_review_repository
    Repositories::FeatureReviewRepository.new
  end

  def git_repository
    git_repository_loader.load(app_name)
  end
end
