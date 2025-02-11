# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CI YML Templates' do
  subject { Gitlab::Ci::YamlProcessor.new(content).execute }

  let(:all_templates) { Gitlab::Template::GitlabCiYmlTemplate.all.map(&:full_name) }

  let(:excluded_templates) do
    all_templates.select do |name|
      Gitlab::Template::GitlabCiYmlTemplate.excluded_patterns.any? { |pattern| pattern.match?(name) }
    end
  end

  context 'when including available templates in a CI YAML configuration' do
    using RSpec::Parameterized::TableSyntax

    where(:template_name) do
      all_templates - excluded_templates
    end

    before do
      stub_feature_flags(
        redirect_to_latest_template_terraform: false,
        redirect_to_latest_template_security_api_fuzzing: false,
        redirect_to_latest_template_security_dast: false)
    end

    with_them do
      let(:content) do
        if template_name == 'Security/DAST-API.gitlab-ci.yml'
          # The DAST-API template purposly excludes a stages
          # definition.

          <<~EOS
            include:
              - template: #{template_name}

            stages:
              - build
              - test
              - deploy
              - dast

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        else
          <<~EOS
            include:
              - template: #{template_name}

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        end
      end

      it 'is valid' do
        expect(subject).to be_valid
      end

      it 'require default stages to be included' do
        expect(subject.stages).to include(*Gitlab::Ci::Config::Entry::Stages.default)
      end
    end
  end

  context 'when including unavailable templates in a CI YAML configuration' do
    using RSpec::Parameterized::TableSyntax

    where(:template_name) do
      excluded_templates
    end

    with_them do
      let(:content) do
        <<~EOS
          include:
            - template: #{template_name}

          concrete_build_implemented_by_a_user:
            stage: test
            script: do something
        EOS
      end

      it 'is not valid' do
        expect(subject).not_to be_valid
      end
    end
  end
end
