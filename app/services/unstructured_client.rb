# frozen_string_literal: true

class UnstructuredClient
  ENDPOINT = "https://api.unstructuredapp.io/general/v0/general"

  def self.extract(file_path)
    api_key = Rails.application.credentials.dig(:unstructured, :api_key) ||
      ENV.fetch("UNSTRUCTURED_API_KEY", nil)

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
    elements = JSON.parse(response.body)
    elements.map { |el| el["text"] }.compact.join("\n\n")
  end
end
