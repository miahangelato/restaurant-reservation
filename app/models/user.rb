class User < ApplicationRecord
  has_secure_password
  
  # Associations
  has_many :reservations, dependent: :destroy
  
  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: :password_required?
  validates :name, presence: true
  validates :phone, presence: true
  validates :role, presence: true, inclusion: { in: %w[customer admin] }
  
  # Callbacks
  before_save :downcase_email
  
  # Scopes
  scope :customers, -> { where(role: 'customer') }
  scope :admins, -> { where(role: 'admin') }
  
  # Methods
  def admin?
    role == 'admin'
  end
  
  def customer?
    role == 'customer'
  end
  
  private
  
  def downcase_email
    self.email = email.downcase
  end
  
  def password_required?
    new_record? || password.present?
  end
end
