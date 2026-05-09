# frozen_string_literal: true

class UnstructuredClient
  ENDPOINT = "https://api.unstructuredapp.io/general/v0/general"

  class ConfigurationError < StandardError; end
  class ApiError < StandardError; end

  def self.extract(file_path)
    api_key = Rails.application.credentials.dig(:unstructured, :api_key) ||
      ENV.fetch("UNSTRUCTURED_API_KEY", nil)

    raise ConfigurationError, "UNSTRUCTURED_API_KEY is not configured" if api_key.blank?

    uri = URI(ENDPOINT)
    request = Net::HTTP::Post.new(uri)
    request["unstructured-api-key"] = api_key
    request["accept"] = "application/json"

    form = Net::HTTP::Post::Multipart.new(
      uri.path,
      "files" => UploadIO.new(file_path, "application/octet-stream", File.basename(file_path))
    )
    form["unstructured-api-key"] = api_key
    form["accept"] = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(form) }
    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "Unstructured API returned #{response.code}: #{response.body.truncate(200)}"
    end

    elements = JSON.parse(response.body)
    elements.map { |el| el["text"] }.compact.join("\n\n")
  end
end
