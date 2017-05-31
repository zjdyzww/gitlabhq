class BuildDetailsEntity < BuildEntity
  expose :coverage, :erased_at, :duration
  expose :tag_list, as: :tags

  expose :erased_by, if: -> (*) { build.erased? }, using: UserEntity
  expose :erase_path, if: -> (*) { build.erasable? && can?(current_user, :update_build, project) } do |build|
    erase_namespace_project_job_path(project.namespace, project, build)
  end

  expose :artifacts, using: BuildArtifactEntity
  expose :runner, using: RunnerEntity
  expose :pipeline, using: PipelineEntity

  expose :merge_request, if: -> (*) { can?(current_user, :read_merge_request, project) } do
    expose :iid do |build|
      build.merge_request.iid
    end

    expose :path do |build|
      namespace_project_merge_request_path(project.namespace, project, build.merge_request)
    end
  end

  expose :new_issue_path, if: -> (*) { can?(request.current_user, :create_issue, project) } do |build|
    new_namespace_project_issue_path(project.namespace, project)
  end

  expose :raw_path do |build|
    raw_namespace_project_build_path(project.namespace, project, build)
  end

  private

  def current_user
    request.current_user
  end

  def project
    build.project
  end
end
