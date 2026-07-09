# Erro de chamada às APIs de calendário (Google/Graph), preservando o status
# HTTP para o tratamento de casos como 410 GONE (sync token inválido).
class Calendar::ApiError < StandardError
  attr_reader :status

  def initialize(message, status: nil)
    @status = status
    super(message)
  end
end
