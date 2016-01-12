class ReleasesController < ApplicationController
  def index
    @app_names = GitRepositoryLocation.app_names
  end

  def show
    redirect_to release_path(app_name, locale: locale) unless params[:locale]
    projection = build_projection
    @pending_releases = projection.pending_releases
    @deployed_releases = projection.deployed_releases
    @app_name = app_name
    @github_repo_url = GitRepositoryLocation.github_url_for_app(app_name)
  rescue GitRepositoryLoader::NotFound
    render text: 'Repository not found', status: :not_found
  end

  private

  def build_projection
    Queries::ReleasesQuery.new(
      per_page: 50,
      locale: locale,
      git_repo: git_repository,
      app_name: app_name)
  end

  def app_name
    params[:id]
  end

  def locale
    params[:locale] || 'uk'
  end

  def git_repository
    git_repository_loader.load(app_name)
  end
end
