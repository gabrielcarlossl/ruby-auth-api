class User < ApplicationRecord
  has_secure_password

  validates :full_name,
            presence: true,
            length: { minimum: 3, maximum: 100 }
  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password,
            length: { minimum: 6 }
            allow_nil: true
  before_save :downcase_email

  private
  def downcase_email
    self.email = email.downcase
  end
end
