# frozen_string_literal: true

class ContactsController < AccountScopedController
  before_action :set_contact, only: [ :show, :update, :destroy ]

  def index
    contacts = @account.contacts.order(:name)
    if params[:q].present?
      query = "%#{params[:q]}%"
      contacts = contacts.where("name ILIKE ? OR email ILIKE ?", query, query)
    end
    render json: { contacts: contacts.map { |c| contact_json(c) } }
  end

  def show
    render json: { contact: contact_json(@contact) }
  end

  def create
    contact = @account.contacts.build(contact_params)
    if contact.save
      render json: { contact: contact_json(contact) }, status: :created
    else
      render json: { errors: contact.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @contact.update(contact_params)
      render json: { contact: contact_json(@contact) }
    else
      render json: { errors: @contact.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    open_requests_count = @contact.booking_requests.where(status: %w[pending reviewing]).count
    if open_requests_count > 0
      return render json: {
        error: "Cannot delete contact with #{open_requests_count} open booking request(s). Close or reassign them first."
      }, status: :unprocessable_entity
    end

    @contact.destroy
    head :no_content
  end

  private

  def set_contact
    @contact = @account.contacts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Contact not found" }, status: :not_found
  end

  def contact_params
    params.require(:contact).permit(:name, :email, :phone)
  end

  def contact_json(contact)
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone: contact.phone,
      created_at: contact.created_at,
      updated_at: contact.updated_at
    }
  end
end
