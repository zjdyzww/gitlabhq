# frozen_string_literal: true
require 'spec_helper'

RSpec.describe API::FeatureFlags do
  include FeatureFlagHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:non_project_member) { create(:user) }
  let(:user) { developer }

  before_all do
    project.add_developer(developer)
    project.add_reporter(reporter)
  end

  shared_examples_for 'check user permission' do
    context 'when user is reporter' do
      let(:user) { reporter }

      it 'forbids the request' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples_for 'not found' do
    it 'returns Not Found' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /projects/:id/feature_flags' do
    subject { get api("/projects/#{project.id}/feature_flags", user) }

    context 'when there are two feature flags' do
      let!(:feature_flag_1) do
        create(:operations_feature_flag, project: project)
      end

      let!(:feature_flag_2) do
        create(:operations_feature_flag, project: project)
      end

      it 'returns feature flags ordered by name' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flags')
        expect(json_response.count).to eq(2)
        expect(json_response.first['name']).to eq(feature_flag_1.name)
        expect(json_response.second['name']).to eq(feature_flag_2.name)
      end

      it 'returns the legacy flag version' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flags')
        expect(json_response.map { |f| f['version'] }).to eq(%w[legacy_flag legacy_flag])
      end

      it 'does not have N+1 problem' do
        control_count = ActiveRecord::QueryRecorder.new { subject }

        create_list(:operations_feature_flag, 3, project: project)

        expect { get api("/projects/#{project.id}/feature_flags", user) }
          .not_to exceed_query_limit(control_count)
      end

      it_behaves_like 'check user permission'
    end

    context 'with version 2 feature flags' do
      let!(:feature_flag) do
        create(:operations_feature_flag, :new_version_flag, project: project, name: 'feature1')
      end

      let!(:strategy) do
        create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
      end

      let!(:scope) do
        create(:operations_scope, strategy: strategy, environment_scope: 'production')
      end

      it 'returns the feature flags' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flags')
        expect(json_response).to eq([{
          'name' => 'feature1',
          'description' => nil,
          'active' => true,
          'version' => 'new_version_flag',
          'updated_at' => feature_flag.updated_at.as_json,
          'created_at' => feature_flag.created_at.as_json,
          'scopes' => [],
          'strategies' => [{
            'id' => strategy.id,
            'name' => 'default',
            'parameters' => {},
            'scopes' => [{
              'id' => scope.id,
              'environment_scope' => 'production'
            }]
          }]
        }])
      end
    end

    context 'with version 1 and 2 feature flags' do
      it 'returns both versions of flags ordered by name' do
        create(:operations_feature_flag, project: project, name: 'legacy_flag')
        feature_flag = create(:operations_feature_flag, :new_version_flag, project: project, name: 'new_version_flag')
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        create(:operations_scope, strategy: strategy, environment_scope: 'production')

        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flags')
        expect(json_response.map { |f| f['name'] }).to eq(%w[legacy_flag new_version_flag])
      end
    end
  end

  describe 'GET /projects/:id/feature_flags/:name' do
    subject { get api("/projects/#{project.id}/feature_flags/#{feature_flag.name}", user) }

    context 'when there is a feature flag' do
      let!(:feature_flag) { create_flag(project, 'awesome-feature') }

      it 'returns a feature flag entry' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response['name']).to eq(feature_flag.name)
        expect(json_response['description']).to eq(feature_flag.description)
        expect(json_response['version']).to eq('legacy_flag')
      end

      context 'without legacy flags' do
        before do
          stub_feature_flags(remove_legacy_flags: true, remove_legacy_flags_override: false)
        end

        it 'returns not found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      it_behaves_like 'check user permission'
    end

    context 'with a version 2 feature_flag' do
      it 'returns the feature flag' do
        feature_flag = create(:operations_feature_flag, :new_version_flag, project: project, name: 'feature1')
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        scope = create(:operations_scope, strategy: strategy, environment_scope: 'production')

        get api("/projects/#{project.id}/feature_flags/feature1", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response).to eq({
          'name' => 'feature1',
          'description' => nil,
          'active' => true,
          'version' => 'new_version_flag',
          'updated_at' => feature_flag.updated_at.as_json,
          'created_at' => feature_flag.created_at.as_json,
          'scopes' => [],
          'strategies' => [{
            'id' => strategy.id,
            'name' => 'default',
            'parameters' => {},
            'scopes' => [{
              'id' => scope.id,
              'environment_scope' => 'production'
            }]
          }]
        })
      end
    end
  end

  describe 'POST /projects/:id/feature_flags' do
    def scope_default
      {
        environment_scope: '*',
        active: false,
        strategies: [{ name: 'default', parameters: {} }].to_json
      }
    end

    subject do
      post api("/projects/#{project.id}/feature_flags", user), params: params
    end

    let(:params) do
      {
        name: 'awesome-feature',
        scopes: [scope_default]
      }
    end

    it 'creates a new feature flag' do
      subject

      expect(response).to have_gitlab_http_status(:created)
      expect(response).to match_response_schema('public_api/v4/feature_flag')

      feature_flag = project.operations_feature_flags.last
      expect(feature_flag.name).to eq(params[:name])
      expect(feature_flag.description).to eq(params[:description])
    end

    it 'defaults to a version 1 (legacy) feature flag' do
      subject

      expect(response).to have_gitlab_http_status(:created)
      expect(response).to match_response_schema('public_api/v4/feature_flag')

      feature_flag = project.operations_feature_flags.last
      expect(feature_flag.version).to eq('legacy_flag')
    end

    it_behaves_like 'check user permission'

    it 'returns version' do
      subject

      expect(response).to have_gitlab_http_status(:created)
      expect(response).to match_response_schema('public_api/v4/feature_flag')
      expect(json_response['version']).to eq('legacy_flag')
    end

    context 'with active set to false in the params for a legacy flag' do
      let(:params) do
        {
          name: 'awesome-feature',
          version: 'legacy_flag',
          active: 'false',
          scopes: [scope_default]
        }
      end

      it 'creates an inactive feature flag' do
        subject

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response['active']).to eq(false)
      end
    end

    context 'when no scopes passed in parameters' do
      let(:params) { { name: 'awesome-feature' } }

      it 'creates a new feature flag with active default scope' do
        subject

        expect(response).to have_gitlab_http_status(:created)
        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.default_scope).to be_active
      end
    end

    context 'when there is a feature flag with the same name already' do
      before do
        create_flag(project, 'awesome-feature')
      end

      it 'fails to create a new feature flag' do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when create a feature flag with two scopes' do
      let(:params) do
        {
          name: 'awesome-feature',
          description: 'this is awesome',
          scopes: [
            scope_default,
            scope_with_user_with_id
          ]
        }
      end

      let(:scope_with_user_with_id) do
        {
          environment_scope: 'production',
          active: true,
          strategies: [{
            name: 'userWithId',
            parameters: { userIds: 'user:1' }
          }].to_json
        }
      end

      it 'creates a new feature flag with two scopes' do
        subject

        expect(response).to have_gitlab_http_status(:created)

        feature_flag = project.operations_feature_flags.last
        feature_flag.scopes.ordered.each_with_index do |scope, index|
          expect(scope.environment_scope).to eq(params[:scopes][index][:environment_scope])
          expect(scope.active).to eq(params[:scopes][index][:active])
          expect(scope.strategies).to eq(Gitlab::Json.parse(params[:scopes][index][:strategies]))
        end
      end
    end

    context 'when creating a version 2 feature flag' do
      it 'creates a new feature flag' do
        params = {
          name: 'new-feature',
          version: 'new_version_flag'
        }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response).to match(hash_including({
          'name' => 'new-feature',
          'description' => nil,
          'active' => true,
          'version' => 'new_version_flag',
          'scopes' => [],
          'strategies' => []
        }))

        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.name).to eq(params[:name])
        expect(feature_flag.version).to eq('new_version_flag')
      end

      it 'creates a new feature flag that is inactive' do
        params = {
          name: 'new-feature',
          version: 'new_version_flag',
          active: false
        }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response['active']).to eq(false)

        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.active).to eq(false)
      end

      it 'creates a new feature flag with strategies' do
        params = {
          name: 'new-feature',
          version: 'new_version_flag',
          strategies: [{
            name: 'userWithId',
            parameters: { 'userIds': 'user1' }
          }]
        }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')

        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.name).to eq(params[:name])
        expect(feature_flag.version).to eq('new_version_flag')
        expect(feature_flag.strategies.map { |s| s.slice(:name, :parameters).deep_symbolize_keys }).to eq([{
          name: 'userWithId',
          parameters: { userIds: 'user1' }
        }])
      end

      it 'creates a new feature flag with gradual rollout strategy with scopes' do
        params = {
          name: 'new-feature',
          version: 'new_version_flag',
          strategies: [{
            name: 'gradualRolloutUserId',
            parameters: { groupId: 'default', percentage: '50' },
            scopes: [{
              environment_scope: 'staging'
            }]
          }]
        }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')

        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.name).to eq(params[:name])
        expect(feature_flag.version).to eq('new_version_flag')
        expect(feature_flag.strategies.map { |s| s.slice(:name, :parameters).deep_symbolize_keys }).to eq([{
          name: 'gradualRolloutUserId',
          parameters: { groupId: 'default', percentage: '50' }
        }])
        expect(feature_flag.strategies.first.scopes.map { |s| s.slice(:environment_scope).deep_symbolize_keys }).to eq([{
          environment_scope: 'staging'
        }])
      end

      it 'creates a new feature flag with flexible rollout strategy with scopes' do
        params = {
          name: 'new-feature',
          version: 'new_version_flag',
          strategies: [{
            name: 'flexibleRollout',
            parameters: { groupId: 'default', rollout: '50', stickiness: 'DEFAULT' },
            scopes: [{
              environment_scope: 'staging'
            }]
          }]
        }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/feature_flag')

        feature_flag = project.operations_feature_flags.last
        expect(feature_flag.name).to eq(params[:name])
        expect(feature_flag.version).to eq('new_version_flag')
        expect(feature_flag.strategies.map { |s| s.slice(:name, :parameters).deep_symbolize_keys }).to eq([{
          name: 'flexibleRollout',
          parameters: { groupId: 'default', rollout: '50', stickiness: 'DEFAULT' }
        }])
        expect(feature_flag.strategies.first.scopes.map { |s| s.slice(:environment_scope).deep_symbolize_keys }).to eq([{
          environment_scope: 'staging'
        }])
      end
    end

    context 'when given invalid parameters' do
      it 'responds with a 400 when given an invalid version' do
        params = { name: 'new-feature', version: 'bad_value' }

        post api("/projects/#{project.id}/feature_flags", user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => 'Version is invalid' })
      end
    end
  end

  describe 'POST /projects/:id/feature_flags/:name/enable' do
    subject do
      post api("/projects/#{project.id}/feature_flags/#{params[:name]}/enable", user),
           params: params
    end

    let(:params) do
      {
        name: 'awesome-feature',
        environment_scope: 'production',
        strategy: { name: 'userWithId', parameters: { userIds: 'Project:1' } }.to_json
      }
    end

    context 'when feature flag does not exist yet' do
      it 'creates a new feature flag with the specified scope and strategy' do
        subject

        feature_flag = project.operations_feature_flags.last
        scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(feature_flag.name).to eq(params[:name])
        expect(scope.strategies).to eq([Gitlab::Json.parse(params[:strategy])])
        expect(feature_flag.version).to eq('legacy_flag')
      end

      it 'returns the flag version and strategies in the json response' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response.slice('version', 'strategies')).to eq({
          'version' => 'legacy_flag',
          'strategies' => []
        })
      end

      it_behaves_like 'check user permission'

      context 'without legacy flags' do
        before do
          stub_feature_flags(remove_legacy_flags: true, remove_legacy_flags_override: false)
        end

        it 'returns not found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when feature flag exists already' do
      let!(:feature_flag) { create_flag(project, params[:name]) }

      context 'when feature flag scope does not exist yet' do
        it 'creates a new scope with the specified strategy' do
          subject

          scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
          expect(response).to have_gitlab_http_status(:ok)
          expect(scope.strategies).to eq([Gitlab::Json.parse(params[:strategy])])
        end

        it_behaves_like 'check user permission'
      end

      context 'when feature flag scope exists already' do
        let(:defined_strategy) { { name: 'userWithId', parameters: { userIds: 'Project:2' } } }

        before do
          create_scope(feature_flag, params[:environment_scope], true, [defined_strategy])
        end

        it 'adds an additional strategy to the scope' do
          subject

          scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
          expect(response).to have_gitlab_http_status(:ok)
          expect(scope.strategies).to eq([defined_strategy.deep_stringify_keys, Gitlab::Json.parse(params[:strategy])])
        end

        context 'when the specified strategy exists already' do
          let(:defined_strategy) { Gitlab::Json.parse(params[:strategy]) }

          it 'does not add a duplicate strategy' do
            subject

            scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
            strategy_count = scope.strategies.count { |strategy| strategy['name'] == 'userWithId' }
            expect(response).to have_gitlab_http_status(:ok)
            expect(strategy_count).to eq(1)
          end
        end
      end

      context 'without legacy flags' do
        before do
          stub_feature_flags(remove_legacy_flags: true, remove_legacy_flags_override: false)
        end

        it 'returns not found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with a version 2 flag' do
      let!(:feature_flag) { create(:operations_feature_flag, :new_version_flag, project: project, name: params[:name]) }

      it 'does not change the flag and returns an unprocessable_entity response' do
        subject

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response).to eq({ 'message' => 'Version 2 flags not supported' })
        feature_flag.reload
        expect(feature_flag.scopes).to eq([])
        expect(feature_flag.strategies).to eq([])
      end
    end
  end

  describe 'POST /projects/:id/feature_flags/:name/disable' do
    subject do
      post api("/projects/#{project.id}/feature_flags/#{params[:name]}/disable", user),
           params: params
    end

    let(:params) do
      {
        name: 'awesome-feature',
        environment_scope: 'production',
        strategy: { name: 'userWithId', parameters: { userIds: 'Project:1' } }.to_json
      }
    end

    context 'when feature flag does not exist yet' do
      it_behaves_like 'not found'
    end

    context 'when feature flag exists already' do
      let!(:feature_flag) { create_flag(project, params[:name]) }

      context 'when feature flag scope does not exist yet' do
        it_behaves_like 'not found'
      end

      context 'when feature flag scope exists already and has the specified strategy' do
        let(:defined_strategies) do
          [
            { name: 'userWithId', parameters: { userIds: 'Project:1' } },
            { name: 'userWithId', parameters: { userIds: 'Project:2' } }
          ]
        end

        before do
          create_scope(feature_flag, params[:environment_scope], true, defined_strategies)
        end

        it 'removes the strategy from the scope' do
          subject

          scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/feature_flag')
          expect(scope.strategies)
            .to eq([{ name: 'userWithId', parameters: { userIds: 'Project:2' } }.deep_stringify_keys])
        end

        it 'returns the flag version and strategies in the json response' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/feature_flag')
          expect(json_response.slice('version', 'strategies')).to eq({
            'version' => 'legacy_flag',
            'strategies' => []
          })
        end

        context 'without legacy flags' do
          before do
            stub_feature_flags(remove_legacy_flags: true, remove_legacy_flags_override: false)
          end

          it 'returns not found' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        it_behaves_like 'check user permission'

        context 'when strategies become empty array after the removal' do
          let(:defined_strategies) do
            [{ name: 'userWithId', parameters: { userIds: 'Project:1' } }]
          end

          it 'destroys the scope' do
            subject

            scope = feature_flag.scopes.find_by_environment_scope(params[:environment_scope])
            expect(response).to have_gitlab_http_status(:ok)
            expect(scope).to be_nil
          end

          it_behaves_like 'check user permission'
        end
      end

      context 'when scope exists already but cannot find the corresponding strategy' do
        let(:defined_strategy) { { name: 'userWithId', parameters: { userIds: 'Project:2' } } }

        before do
          create_scope(feature_flag, params[:environment_scope], true, [defined_strategy])
        end

        it_behaves_like 'not found'
      end
    end

    context 'with a version 2 feature flag' do
      let!(:feature_flag) { create(:operations_feature_flag, :new_version_flag, project: project, name: params[:name]) }

      it 'does not change the flag and returns an unprocessable_entity response' do
        subject

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response).to eq({ 'message' => 'Version 2 flags not supported' })
        feature_flag.reload
        expect(feature_flag.scopes).to eq([])
        expect(feature_flag.strategies).to eq([])
      end
    end
  end

  describe 'PUT /projects/:id/feature_flags/:name' do
    context 'with a legacy feature flag' do
      let!(:feature_flag) do
        create(:operations_feature_flag, :legacy_flag, project: project,
               name: 'feature1', description: 'old description')
      end

      it 'returns a 422' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response).to eq({ 'message' => 'PUT operations are not supported for legacy feature flags' })
        expect(feature_flag.reload.description).to eq('old description')
      end
    end

    context 'with a version 2 feature flag' do
      let!(:feature_flag) do
        create(:operations_feature_flag, :new_version_flag, project: project, active: true,
               name: 'feature1', description: 'old description')
      end

      it 'returns a 404 if the feature flag does not exist' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/other_flag_name", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(feature_flag.reload.description).to eq('old description')
      end

      it 'forbids a request for a reporter' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/feature1", reporter), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(feature_flag.reload.description).to eq('old description')
      end

      it 'returns an error for an invalid update of gradual rollout' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            id: strategy.id,
            name: 'gradualRolloutUserId',
            parameters: { bad: 'params' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).not_to be_nil
        result = feature_flag.reload.strategies.map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
        expect(result).to eq([{
          id: strategy.id,
          name: 'default',
          parameters: {}
        }])
      end

      it 'returns an error for an invalid update of flexible rollout' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            id: strategy.id,
            name: 'flexibleRollout',
            parameters: { bad: 'params' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).not_to be_nil
        result = feature_flag.reload.strategies.map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
        expect(result).to eq([{
          id: strategy.id,
          name: 'default',
          parameters: {}
        }])
      end

      it 'updates the feature flag' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(feature_flag.reload.description).to eq('new description')
      end

      it 'updates the flag active value' do
        params = { active: false }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response['active']).to eq(false)
        expect(feature_flag.reload.active).to eq(false)
      end

      it 'updates the feature flag name' do
        params = { name: 'new-name' }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(json_response['name']).to eq('new-name')
        expect(feature_flag.reload.name).to eq('new-name')
      end

      it 'ignores a provided version parameter' do
        params = { description: 'other description', version: 'bad_value' }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(feature_flag.reload.description).to eq('other description')
      end

      it 'returns the feature flag json' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        feature_flag.reload
        expect(json_response).to eq({
          'name' => 'feature1',
          'description' => 'new description',
          'active' => true,
          'created_at' => feature_flag.created_at.as_json,
          'updated_at' => feature_flag.updated_at.as_json,
          'scopes' => [],
          'strategies' => [],
          'version' => 'new_version_flag'
        })
      end

      it 'updates an existing feature flag strategy to be gradual rollout strategy' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            id: strategy.id,
            name: 'gradualRolloutUserId',
            parameters: { groupId: 'default', percentage: '10' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies.map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
        expect(result).to eq([{
          id: strategy.id,
          name: 'gradualRolloutUserId',
          parameters: { groupId: 'default', percentage: '10' }
        }])
      end

      it 'updates an existing feature flag strategy to be flexible rollout strategy' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            id: strategy.id,
            name: 'flexibleRollout',
            parameters: { groupId: 'default', rollout: '10', stickiness: 'DEFAULT' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies.map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
        expect(result).to eq([{
          id: strategy.id,
          name: 'flexibleRollout',
          parameters: { groupId: 'default', rollout: '10', stickiness: 'DEFAULT' }
        }])
      end

      it 'adds a new gradual rollout strategy to a feature flag' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            name: 'gradualRolloutUserId',
            parameters: { groupId: 'default', percentage: '10' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies
          .map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
          .sort_by { |s| s[:name] }
        expect(result.first[:id]).to eq(strategy.id)
        expect(result.map { |s| s.slice(:name, :parameters) }).to eq([{
          name: 'default',
          parameters: {}
        }, {
          name: 'gradualRolloutUserId',
          parameters: { groupId: 'default', percentage: '10' }
        }])
      end

      it 'adds a new gradual flexible strategy to a feature flag' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        params = {
          strategies: [{
            name: 'flexibleRollout',
            parameters: { groupId: 'default', rollout: '10', stickiness: 'DEFAULT' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies
          .map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
          .sort_by { |s| s[:name] }
        expect(result.first[:id]).to eq(strategy.id)
        expect(result.map { |s| s.slice(:name, :parameters) }).to eq([{
          name: 'default',
          parameters: {}
        }, {
          name: 'flexibleRollout',
          parameters: { groupId: 'default', rollout: '10', stickiness: 'DEFAULT' }
        }])
      end

      it 'deletes a feature flag strategy' do
        strategy_a = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        strategy_b = create(:operations_strategy, feature_flag: feature_flag,
                          name: 'userWithId', parameters: { userIds: 'userA,userB' })
        params = {
          strategies: [{
            id: strategy_a.id,
            name: 'default',
            parameters: {},
            _destroy: true
          }, {
            id: strategy_b.id,
            name: 'userWithId',
            parameters: { userIds: 'userB' }
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies
          .map { |s| s.slice(:id, :name, :parameters).deep_symbolize_keys }
          .sort_by { |s| s[:name] }
        expect(result).to eq([{
          id: strategy_b.id,
          name: 'userWithId',
          parameters: { userIds: 'userB' }
        }])
      end

      it 'updates an existing feature flag scope' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        scope = create(:operations_scope, strategy: strategy, environment_scope: '*')
        params = {
          strategies: [{
            id: strategy.id,
            scopes: [{
              id: scope.id,
              environment_scope: 'production'
            }]
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        result = feature_flag.reload.strategies.first.scopes.map { |s| s.slice(:id, :environment_scope).deep_symbolize_keys }
        expect(result).to eq([{
          id: scope.id,
          environment_scope: 'production'
        }])
      end

      it 'deletes an existing feature flag scope' do
        strategy = create(:operations_strategy, feature_flag: feature_flag, name: 'default', parameters: {})
        scope = create(:operations_scope, strategy: strategy, environment_scope: '*')
        params = {
          strategies: [{
            id: strategy.id,
            scopes: [{
              id: scope.id,
              _destroy: true
            }]
          }]
        }

        put api("/projects/#{project.id}/feature_flags/feature1", user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/feature_flag')
        expect(feature_flag.reload.strategies.first.scopes.count).to eq(0)
      end
    end

    context 'without legacy flags' do
      before do
        stub_feature_flags(remove_legacy_flags: true, remove_legacy_flags_override: false)
      end

      it 'returns not found' do
        params = { description: 'new description' }

        put api("/projects/#{project.id}/feature_flags/other_flag_name", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /projects/:id/feature_flags/:name' do
    subject do
      delete api("/projects/#{project.id}/feature_flags/#{feature_flag.name}", user),
             params: params
    end

    let!(:feature_flag) { create(:operations_feature_flag, project: project) }
    let(:params) { {} }

    it 'destroys the feature flag' do
      expect { subject }.to change { Operations::FeatureFlag.count }.by(-1)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'returns version' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['version']).to eq('legacy_flag')
    end

    context 'with a version 2 feature flag' do
      let!(:feature_flag) { create(:operations_feature_flag, :new_version_flag, project: project) }

      it 'destroys the flag' do
        expect { subject }.to change { Operations::FeatureFlag.count }.by(-1)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
