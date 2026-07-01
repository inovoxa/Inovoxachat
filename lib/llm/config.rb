require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  # Provedores extras (além do OpenAI). O RubyLLM resolve o provedor pelo nome do modelo
  # (registry em config/llm_models.json). Ex.: model "deepseek/deepseek-chat" usa OpenRouter.
  # OpenRouter é agregador: com uma key só, dá acesso a deepseek, grok, gpt, claude, gemini…
  PROVIDER_API_KEYS = {
    openrouter: 'CAPTAIN_OPENROUTER_API_KEY',
    anthropic: 'CAPTAIN_ANTHROPIC_API_KEY',
    gemini: 'CAPTAIN_GEMINI_API_KEY',
    deepseek: 'CAPTAIN_DEEPSEEK_API_KEY'
  }.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        configure_extra_providers(config)
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
    end

    # Configura as keys dos provedores extras (OpenRouter, Anthropic, Gemini, DeepSeek)
    # a partir das InstallationConfigs, quando presentes.
    def configure_extra_providers(config)
      PROVIDER_API_KEYS.each do |provider, config_name|
        key = InstallationConfig.find_by(name: config_name)&.value
        next if key.blank?

        setter = "#{provider}_api_key="
        config.public_send(setter, key) if config.respond_to?(setter)
      end
      apply_openrouter_compatibility(config)
    end

    # Compatibilidade: modelos com id estilo OpenRouter (ex.: "openai/gpt-4o-mini",
    # "deepseek/deepseek-chat") são resolvidos pelo RubyLLM como provider :openrouter, que
    # exige openrouter_api_key. Se o endpoint aponta para o OpenRouter e o slot nativo
    # (CAPTAIN_OPENROUTER_API_KEY) está vazio, reutilizamos a CAPTAIN_OPEN_AI_API_KEY
    # (que na prática é a key do OpenRouter) — assim o setup "OpenAI-compatible" funciona.
    def apply_openrouter_compatibility(config)
      return unless config.respond_to?(:openrouter_api_key=)
      return unless openrouter_endpoint?
      return if InstallationConfig.find_by(name: PROVIDER_API_KEYS[:openrouter])&.value.present?
      return if system_api_key.blank?

      config.openrouter_api_key = system_api_key
    end

    def openrouter_endpoint?
      openai_endpoint.to_s.include?('openrouter.ai')
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
