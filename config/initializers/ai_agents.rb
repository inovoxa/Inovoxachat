# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL
  api_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value || LlmConstants::OPENAI_API_ENDPOINT

  if api_key.present?
    Agents.configure do |config|
      config.openai_api_key = api_key
      if api_endpoint.present?
        base = api_endpoint.chomp('/')
        # Não duplicar /v1 quando o endpoint já termina em /v1 (ex.: OpenRouter).
        config.openai_api_base = base.end_with?('/v1') ? base : "#{base}/v1"
      end
      config.default_model = model
      config.debug = false
      # OpenRouter: se o endpoint é do OpenRouter e a key nativa não foi definida,
      # reutiliza a mesma key (que é a do OpenRouter) no slot correto.
      if config.respond_to?(:openrouter_api_key=) &&
         api_endpoint.to_s.include?('openrouter.ai') &&
         InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_API_KEY')&.value.blank?
        config.openrouter_api_key = api_key
      end
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
