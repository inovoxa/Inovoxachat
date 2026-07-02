# Campos de negócio para o módulo de locação: CNPJ, status do cliente, responsável (agente),
# telefone e endereço. Reversível.
class AddBusinessFieldsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :cnpj, :string
    add_column :companies, :status, :integer, default: 0, null: false
    add_column :companies, :account_owner_id, :bigint
    add_column :companies, :phone, :string
    add_column :companies, :address, :text

    add_index :companies, [:account_id, :status]
    add_index :companies, :account_owner_id
    add_index :companies, [:account_id, :cnpj], unique: true, where: 'cnpj IS NOT NULL',
                          name: 'index_companies_on_account_and_cnpj'
  end
end
