# Policy for Product authorization in e-commerce app
class ProductPolicy < ApplicationPolicy
  def index?
    true  # Everyone can browse products
  end

  def show?
    true  # Everyone can view product details
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def permitted_attributes
    admin? ? [:name, :description, :price, :cost, :inventory, :active, :category_id] : []
  end

  def visible_attributes
    if admin?
      [:id, :name, :description, :price, :cost, :inventory, :active, :created_at]
    else
      [:id, :name, :description, :price]  # Hide cost and inventory from customers
    end
  end

  def editable_attributes
    admin? ? [:name, :description, :price, :cost, :inventory, :active] : []
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all  # Admins see all products
      else
        scope.where(active: true)  # Customers see only active products
      end
    end
  end
end
