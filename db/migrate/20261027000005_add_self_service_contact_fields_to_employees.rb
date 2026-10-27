class AddSelfServiceContactFieldsToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_column :employees, :phone, :string
    add_column :employees, :personal_email, :string
    add_column :employees, :address, :text
    add_column :employees, :emergency_contact, :string
  end
end
