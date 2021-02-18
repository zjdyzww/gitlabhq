# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User searches their settings', :js do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  context 'in profile page' do
    let(:visit_path) { profile_path }

    it_behaves_like 'can search settings with feature flag check', 'Public Avatar', 'Main settings'
  end

  context 'in preferences page' do
    before do
      visit profile_preferences_path
    end

    it_behaves_like 'can search settings', 'Syntax highlighting theme', 'Behavior'
  end
end
