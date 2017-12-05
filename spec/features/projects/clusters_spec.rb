require 'spec_helper'

feature 'Clusters', :js do
  include GoogleApi::CloudPlatformHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    project.add_master(user)
    gitlab_sign_in(user)
  end

  context 'when user does not have a cluster and visits cluster index page' do
    before do
      visit project_clusters_path(project)
    end

    it 'sees empty state' do
      expect(page).to have_link('Add cluster')
      expect(page).to have_selector('.empty-state')
    end
  end

  context 'when user has a cluster and visits cluster index page' do
    let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
    let(:project) { cluster.project }
  
    before do
      visit project_clusters_path(project)
    end
  
    it 'user sees a disabled add cluster button ' do
      expect(page).to have_selector('.js-add-cluster.disabled')
    end
    
    context 'inline update of cluster' do
      it 'user can update cluster' do
        expect(page).to have_selector('.js-toggle-cluster-list')
      end
  
      context 'with sucessfull request' do
        it 'user sees updated cluster' do
          expect do
            page.find('.js-toggle-cluster-list').click
            wait_for_requests
          end.to change { cluster.reload.enabled }
  
          expect(page).not_to have_selector('.is-checked')
          expect(cluster.reload).not_to be_enabled
        end
      end
  
      context 'with failed request' do
        it 'user sees not update cluster and error message' do
          expect_any_instance_of(Clusters::UpdateService).to receive(:execute).and_call_original
          allow_any_instance_of(Clusters::Cluster).to receive(:valid?) { false }

          page.find('.js-toggle-cluster-list').click

          expect(page).to have_content('Something went wrong on our end.')
          expect(page).to have_selector('.is-checked')
          expect(cluster.reload).to be_enabled
        end
      end
    end
  
    context 'when user clicks on a cluster' do
      before do
        click_link cluster.name
      end
  
      it 'user sees a cluster details page' do
        expect(page).to have_button('Save')
        expect(page.find(:css, '.cluster-name').value).to eq(cluster.name)
      end
    end
  end  
end
