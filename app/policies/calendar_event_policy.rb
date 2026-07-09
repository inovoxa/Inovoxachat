class CalendarEventPolicy < ApplicationPolicy
  # Todo membro da conta (admin ou agente) enxerga e cria eventos — visibilidade
  # de equipe. A restrição fica na edição/remoção.
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator? || @account_user.agent?
  end

  # Só o dono do evento ou um administrador altera/remove — agente não mexe na
  # agenda alheia.
  def update?
    @account_user.administrator? || record.user_id == @user.id
  end

  def destroy?
    update?
  end
end
