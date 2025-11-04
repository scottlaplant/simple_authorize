# Policy for Order authorization in e-commerce app
class OrderPolicy < ApplicationPolicy
  def index?
    logged_in?  # Must be logged in to view orders
  end

  def show?
    admin? || owner?  # View own orders or admin views all
  end

  def create?
    logged_in?  # Must be logged in to create orders
  end

  def update?
    admin?  # Only admins can update orders
  end

  def destroy?
    admin?  # Only admins can delete orders
  end

  # Custom actions

  def cancel?
    return true if admin?
    owner? && record.status == "pending"  # Can only cancel pending orders
  end

  def ship?
    admin?  # Only admins can mark as shipped
  end

  def refund?
    admin?  # Only admins can process refunds
  end

  def permitted_attributes
    if admin?
      [:status, :shipping_address, :tracking_number, :notes]
    elsif owner? && record.status == "pending"
      [:shipping_address]  # Customers can update address before shipping
    else
      []
    end
  end

  def visible_attributes
    if admin?
      [:id, :user_id, :status, :total, :shipping_address, :tracking_number, :notes, :created_at, :updated_at]
    elsif owner?
      [:id, :status, :total, :shipping_address, :tracking_number, :created_at]
    else
      []
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all  # Admins see all orders
      else
        scope.where(user_id: user&.id)  # Customers see only their orders
      end
    end
  end
end
