require 'rails_helper'
require 'git_repository_loader'
require 'support/git_test_repository'

RSpec.describe GitRepositoryLoader do
  let(:cache_dir) { Dir.mktmpdir }

  subject(:git_repository_loader) { GitRepositoryLoader.new(cache_dir: cache_dir) }

  describe '#load' do
    let(:test_git_repo) { Support::GitTestRepository.new }
    let(:repo_uri) { "file://#{test_git_repo.dir}" }
    let(:repo_name) { test_git_repo.dir.split('/').last }
    let!(:git_repository_location) { GitRepositoryLocation.create(uri: repo_uri) }

    before do
      test_git_repo.create_commit
      git_repository_location.update(remote_head: test_git_repo.head_oid)
    end

    it 'returns a GitRepository' do
      expect(git_repository_loader.load(repo_name)).to be_a(GitRepository)
    end

    context 'when the repository location does not exist' do
      it 'raises a NotFound exception' do
        expect {
          git_repository_loader.load('non-existent-repo')
        }.to raise_error(GitRepositoryLoader::NotFound)
      end
    end

    context 'when the repository has not been cloned yet' do
      it 'should clone it' do
        expect(Rugged::Repository).to receive(:clone_at).once

        git_repository_loader.load(repo_name)
      end
    end

    context 'when the repository has already been cloned' do
      before do
        git_repository_loader.load(repo_name)
      end

      context 'when the local copy is up-to-date' do
        it 'should do nothing' do
          expect(Rugged::Repository).to_not receive(:clone_at)
          expect_any_instance_of(Rugged::Repository).to_not receive(:fetch)

          git_repository_loader.load(repo_name)
        end
      end

      context 'when the local copy is not up-to-date' do
        before do
          create_remote_commit
        end

        it 'should fetch the repository' do
          expect(Rugged::Repository).to_not receive(:clone_at)
          expect_any_instance_of(Rugged::Repository).to receive(:fetch).once

          git_repository_loader.load(repo_name)
        end
      end

      context 'when the local copy HEAD points to a ref that does not exist' do
        before do
          allow_any_instance_of(Rugged::Repository).to receive(:head).and_raise(Rugged::ReferenceError)
        end

        it 'clones the repo instead of fetching it to continue the update' do
          expect(Rugged::Repository).to receive(:clone_at).once

          git_repository_loader.load(repo_name)
        end
      end
    end

    context 'when the destination directory is not empty and is not a git repo' do
      it 'removes the destination directory before cloning' do
        git_repository = git_repository_loader.load(repo_name)

        # Screw up the git repository
        path = git_repository.path
        FileUtils.rm_rf(path)
        Dir.mkdir(path)
        File.open(File.join(path, 'foo.txt'), 'w') do |f| f.write('foo') end

        # Reload the git repository
        expect { git_repository_loader.load(repo_name) }.not_to raise_error
      end
    end

    context 'with an HTTP URI' do
      let(:repo_uri) { 'http://example.com/some_repo.git' }

      it 'should not use credentials' do
        expect(Rugged::Repository).to receive(:clone_at) do |_uri, _dir, options|
          expect(options).to_not have_key(:credentials)
        end

        git_repository_loader.load('some_repo')
      end
    end

    context 'with an SSH URI' do
      let(:repo_uri) { 'ssh://example.com/some_repo.git' }
      let(:ssh_private_key) { 'PR1V4t3' }
      let(:ssh_public_key) { 'PU8L1C' }
      let(:ssh_user) { 'alice' }

      subject(:git_repository_loader) {
        GitRepositoryLoader.new(
          cache_dir: cache_dir,
          ssh_private_key: ssh_private_key,
          ssh_public_key: ssh_public_key,
          ssh_user: ssh_user,
        )
      }

      it 'uses the correct credentials' do
        private_key_file = nil
        public_key_file = nil

        expect(Rugged::Repository).to receive(:clone_at) do |uri, _directory, options|
          # This is a Rugged::Credentials object which is a C extension
          # We need to delve into the internals of this to check it is the correct credentials object\
          # that is being passed to the clone method
          credentials = options.fetch(:credentials)
          username = credentials.instance_variable_get(:@username)
          private_key_file = credentials.instance_variable_get(:@privatekey)
          public_key_file = credentials.instance_variable_get(:@publickey)

          expect(uri).to eq(repo_uri)

          expect(username).to eq(ssh_user)

          expect(File.read(private_key_file)).to eq(ssh_private_key + "\n")
          expect(File.stat(private_key_file)).to_not be_world_readable

          expect(File.read(public_key_file)).to eq(ssh_public_key + "\n")
          expect(File.stat(public_key_file)).to_not be_world_readable
        end

        git_repository_loader.load('some_repo')

        expect(File.exist?(private_key_file)).to be(false), 'The privatekey file should be cleaned up'
      end

      context 'when ssh_private_key is missing' do
        let(:ssh_private_key) { nil }

        it 'raises an error' do
          expect { git_repository_loader.load('some_repo') }.to raise_error('ssh_private_key not set')
        end
      end

      context 'when ssh_public_key is missing' do
        let(:ssh_public_key) { nil }

        it 'raises an error' do
          expect { git_repository_loader.load('some_repo') }.to raise_error('ssh_public_key not set')
        end
      end

      context 'when ssh_user is missing' do
        let(:ssh_user) { nil }

        it 'raises an error' do
          expect { git_repository_loader.load('some_repo') }.to raise_error('ssh_user not set')
        end
      end
    end
  end

  def create_remote_commit
    test_git_repo.create_commit
    git_repository_location.update(remote_head: test_git_repo.head_oid)
  end
end
