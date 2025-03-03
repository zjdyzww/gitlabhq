# frozen_string_literal: true

module API
  class DebianProjectPackages < ::API::Base
    params do
      requires :id, type: String, desc: 'The ID of a project'
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      before do
        require_packages_enabled!

        not_found! unless ::Feature.enabled?(:debian_packages, user_project)

        authorize_read_package!
      end

      namespace ':id' do
        include ::API::Concerns::Packages::DebianEndpoints

        params do
          requires :file_name, type: String, desc: 'The file name'
        end

        namespace 'packages/debian/:file_name', requirements: FILE_NAME_REQUIREMENTS do
          content_type :json, Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

          # PUT {projects|groups}/:id/packages/debian/:file_name
          params do
            requires :file, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)'
          end

          route_setting :authentication, deploy_token_allowed: true, basic_auth_personal_access_token: true, job_token_allowed: :basic_auth, authenticate_non_public: true
          put do
            authorize_upload!(authorized_user_project)
            bad_request!('File is too large') if authorized_user_project.actual_limits.exceeded?(:debian_max_file_size, params[:file].size)

            track_package_event('push_package', :debian, user: current_user, project: authorized_user_project, namespace: authorized_user_project.namespace)

            file_params = {
              file:        params['file'],
              file_name:   params['file_name'],
              file_sha1:   params['file.sha1'],
              file_md5:    params['file.md5']
            }

            package = ::Packages::Debian::FindOrCreateIncomingService.new(authorized_user_project, current_user).execute

            package_file = ::Packages::Debian::CreatePackageFileService.new(package, file_params).execute

            if params['file_name'].end_with? '.changes'
              ::Packages::Debian::ProcessChangesWorker.perform_async(package_file.id, current_user.id) # rubocop:disable CodeReuse/Worker
            end

            created!
          rescue ObjectStorage::RemoteStoreError => e
            Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: authorized_user_project.id })

            forbidden!
          end

          # PUT {projects|groups}/:id/packages/debian/:file_name/authorize
          route_setting :authentication, deploy_token_allowed: true, basic_auth_personal_access_token: true, job_token_allowed: :basic_auth, authenticate_non_public: true
          put 'authorize' do
            authorize_workhorse!(
              subject: authorized_user_project,
              maximum_size: authorized_user_project.actual_limits.debian_max_file_size
            )
          end
        end
      end
    end
  end
end
