# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Clients::Http do
  include ImportSpecHelper

  let(:uri) { 'http://gitlab.example' }
  let(:token) { 'token' }
  let(:resource) { 'resource' }
  let(:response_double) { double(code: 200, success?: true, parsed_response: {}) }

  subject { described_class.new(uri: uri, token: token) }

  shared_examples 'performs network request' do
    it 'performs network request' do
      expect(Gitlab::HTTP).to receive(method).with(*expected_args).and_return(response_double)

      subject.public_send(method, resource)
    end

    context 'error handling' do
      context 'when error occurred' do
        it 'raises ConnectionError' do
          allow(Gitlab::HTTP).to receive(method).and_raise(Errno::ECONNREFUSED)

          expect { subject.public_send(method, resource) }.to raise_exception(described_class::ConnectionError)
        end
      end

      context 'when response is not success' do
        it 'raises ConnectionError' do
          response_double = double(code: 503, success?: false)

          allow(Gitlab::HTTP).to receive(method).and_return(response_double)

          expect { subject.public_send(method, resource) }.to raise_exception(described_class::ConnectionError)
        end
      end
    end
  end

  describe '#get' do
    let(:method) { :get }

    include_examples 'performs network request' do
      let(:expected_args) do
        [
          'http://gitlab.example:80/api/v4/resource',
          hash_including(
            follow_redirects: false,
            query: {
              page: described_class::DEFAULT_PAGE,
              per_page: described_class::DEFAULT_PER_PAGE
            },
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}"
            }
          )
        ]
      end
    end

    describe '#each_page' do
      let(:objects1) { [{ object: 1 }, { object: 2 }] }
      let(:objects2) { [{ object: 3 }, { object: 4 }] }
      let(:response1) { double(success?: true, headers: { 'x-next-page' => 2 }, parsed_response: objects1) }
      let(:response2) { double(success?: true, headers: {}, parsed_response: objects2) }

      before do
        stub_http_get('groups', { page: 1, per_page: 30 }, response1)
        stub_http_get('groups', { page: 2, per_page: 30 }, response2)
      end

      context 'with a block' do
        it 'yields every retrieved page to the supplied block' do
          pages = []

          subject.each_page(:get, 'groups') { |page| pages << page }

          expect(pages[0]).to be_an_instance_of(Array)
          expect(pages[1]).to be_an_instance_of(Array)

          expect(pages[0]).to eq(objects1)
          expect(pages[1]).to eq(objects2)
        end
      end

      context 'without a block' do
        it 'returns an Enumerator' do
          expect(subject.each_page(:get, :foo)).to be_an_instance_of(Enumerator)
        end
      end

      private

      def stub_http_get(path, query, response)
        uri = "http://gitlab.example:80/api/v4/#{path}"
        params = {
          follow_redirects: false,
          headers: {
            "Authorization" => "Bearer token",
            "Content-Type" => "application/json"
          }
        }.merge(query: query)

        allow(Gitlab::HTTP).to receive(:get).with(uri, params).and_return(response)
      end
    end
  end

  describe '#post' do
    let(:method) { :post }

    include_examples 'performs network request' do
      let(:expected_args) do
        [
          'http://gitlab.example:80/api/v4/resource',
          hash_including(
            body: {},
            follow_redirects: false,
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}"
            }
          )
        ]
      end
    end
  end

  describe '#head' do
    let(:method) { :head }

    include_examples 'performs network request' do
      let(:expected_args) do
        [
          'http://gitlab.example:80/api/v4/resource',
          hash_including(
            follow_redirects: false,
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}"
            }
          )
        ]
      end
    end
  end

  describe '#stream' do
    it 'performs network request with stream_body option' do
      expected_args = [
        'http://gitlab.example:80/api/v4/resource',
        hash_including(
          stream_body: true,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{token}"
          }
        )
      ]

      expect(Gitlab::HTTP).to receive(:get).with(*expected_args).and_return(response_double)

      subject.stream(resource)
    end
  end
end
