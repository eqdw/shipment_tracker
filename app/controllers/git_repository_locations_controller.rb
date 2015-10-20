class GitRepositoryLocationsController < ApplicationController
  def index
    @new_git_repository_location = GitRepositoryLocation.new
    @git_repository_locations = GitRepositoryLocation.all.order(:name)
  end

  def create
    @new_git_repository_location = GitRepositoryLocation.new(git_repository_location_params)
    if @new_git_repository_location.save
      redirect_to :git_repository_locations
    else
      @git_repository_locations = GitRepositoryLocation.all
      flash.now[:error] = @new_git_repository_location.errors.full_messages.to_sentence
      render :index
    end
  end

  private

  def git_repository_location_params
    params.require(:git_repository_location).permit(:uri)
  end
end
