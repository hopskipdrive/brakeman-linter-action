# frozen_string_literal: true

class GithubCheckRunService
  CHECK_NAME = 'Brakeman'
  MAX_ANNOTATIONS_SIZE = 50

  def initialize(report, github_data, report_adapter)
    @report = report
    @github_data = github_data
    @report_adapter = report_adapter
    @client = GithubClient.new(@github_data[:token], user_agent: 'brakeman-action')
  end

  def run
    id = @client.post(
      endpoint_url,
      create_check_payload
    )['id']
    @summary = @report_adapter.summary(@report)
    @conclusion = @report_adapter.conclusion(@report)

    pp '$' * 20
    pp '%' * 20

    result = {}

    if @conclusion == 'success'
      result.merge(client_patch(id))
    else
      @annotations = @report_adapter.annotations(@report)
      @annotations.each_slice(MAX_ANNOTATIONS_SIZE) do |annotations|
        result.merge(client_patch(id, annotations))
      end
    end

    result
  end

  private

  def client_patch(id, annotations=nil)
    @client.patch(
      "#{endpoint_url}/#{id}",
      update_check_payload(annotations)
    )
  end

  def endpoint_url
    "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/check-runs"
  end

  def create_check_payload
    {
      name: CHECK_NAME,
      head_sha: @github_data[:sha],
      status: 'in_progress',
      started_at: Time.now.iso8601
    }
  end

  def update_check_payload(annotations=nil)
    if annotations
      {
        name: CHECK_NAME,
        head_sha: @github_data[:sha],
        status: 'completed',
        completed_at: Time.now.iso8601,
        conclusion: @conclusion,
        output: {
          title: CHECK_NAME,
          summary: @summary,
          annotations: annotations
        }
      }
    else
      {
        name: CHECK_NAME,
        head_sha: @github_data[:sha],
        status: 'completed',
        completed_at: Time.now.iso8601,
        conclusion: @conclusion,
        output: {
          title: CHECK_NAME,
          summary: @summary
        }
      }
    end
  end
end
