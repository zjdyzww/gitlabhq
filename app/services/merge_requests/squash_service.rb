require 'securerandom'

module MergeRequests
  class SquashService < MergeRequests::WorkingCopyBaseService
    attr_reader :repository, :rugged

    def execute(merge_request)
      @merge_request = merge_request
      @repository = target_project.repository
      @rugged = repository.rugged

      squash || error('Failed to squash. Should be done manually')
    end

    def squash
      # We will push to this ref, then immediately delete the ref. This is
      # because we don't want a new branch to appear in the UI - we just want
      # the commit to be present in the repo.
      #
      # Squashing would ideally be possible by applying a patch to a bare repo
      # and creating a commit object, in which case wouldn't need this dance.
      #
      temp_branch = SecureRandom.uuid

      if merge_request.squash_in_progress?
        log_error('Squash task canceled: Another squash is already in progress')
        return false
      end

      run_git_command(
        %W(clone -b #{merge_request.target_branch} -- #{repository.path_to_repo} #{tree_path}),
        nil,
        git_env,
        'clone repository for squash'
      )

      run_git_command(%w(apply --cached), tree_path, git_env, 'apply patch') do |stdin|
        stdin.puts(merge_request_to_patch)
      end

      run_git_command(
        %W(commit -C #{merge_request.diff_head_sha}),
        tree_path,
        git_env.merge('GIT_COMMITTER_NAME' => current_user.name, 'GIT_COMMITTER_EMAIL' => current_user.email),
        'commit squashed changes'
      )

      squash_sha = run_git_command(
        %w(rev-parse HEAD),
        tree_path,
        git_env,
        "get SHA of squashed branch #{temp_branch}"
      )

      run_git_command(
        %W(push -f origin HEAD:#{temp_branch}),
        tree_path,
        git_env,
        'push squashed branch'
      )

      repository.rm_branch(current_user, temp_branch)

      success(squash_sha: squash_sha)
    rescue GitCommandError
      false
    rescue => e
      log_error("Failed to squash merge request #{merge_request.to_reference(full: true)}:")
      log_error(e.message)
      false
    ensure
      clean_dir
    end

    def tree_path
      @tree_path ||= merge_request.squash_dir_path
    end

    def merge_request_to_patch
      @merge_request_to_patch ||= rugged.diff(merge_request.diff_base_sha, merge_request.diff_head_sha).patch
    end
  end
end
