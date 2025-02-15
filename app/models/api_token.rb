class APIToken < ApplicationRecord
  include ActiveRecord::SecureToken

  belongs_to :administrateur, inverse_of: :api_tokens

  before_save :sanitize_targeted_procedure_ids

  def context
    {
      administrateur_id:,
      api_token_id: id,
      procedure_ids:,
      write_access:
    }
  end

  def procedure_ids
    if full_access?
      administrateur.procedures.ids
    else
      sanitized_targeted_procedure_ids
    end
  end

  def procedures
    Procedure.where(id: procedure_ids)
  end

  def full_access?
    targeted_procedure_ids.nil?
  end

  def targetable_procedures
    administrateur
      .procedures
      .where.not(id: targeted_procedure_ids)
      .select(:id, :libelle, :path)
      .order(:libelle)
  end

  def untarget_procedure(procedure_id)
    new_target_ids = targeted_procedure_ids - [procedure_id]

    update!(allowed_procedure_ids: new_target_ids)
  end

  def sanitized_targeted_procedure_ids
    administrateur.procedures.ids.intersection(targeted_procedure_ids || [])
  end

  def become_full_access!
    update_column(:allowed_procedure_ids, nil)
  end

  # Prefix is made of the first 6 characters of the uuid base64 encoded
  # it does not leak plain token
  def prefix
    Base64.urlsafe_encode64(id).slice(0, 5)
  end

  class << self
    def generate(administrateur)
      plain_token = generate_unique_secure_token
      encrypted_token = BCrypt::Password.create(plain_token)
      api_token = create!(administrateur:, encrypted_token:, name: Date.today.strftime('Jeton d’API généré le %d/%m/%Y'))
      bearer = BearerToken.new(api_token.id, plain_token)
      [api_token, bearer.to_string]
    end

    def authenticate(bearer_string)
      bearer = BearerToken.from_string(bearer_string)

      return if bearer.nil?

      api_token = find_by(id: bearer.api_token_id, version: 3)

      return if api_token.nil?

      BCrypt::Password.new(api_token.encrypted_token) == bearer.plain_token ? api_token : nil
    end
  end

  private

  def sanitize_targeted_procedure_ids
    if targeted_procedure_ids.present?
      write_attribute(:allowed_procedure_ids, sanitized_targeted_procedure_ids)
    end
  end

  def targeted_procedure_ids
    read_attribute(:allowed_procedure_ids)
  end

  class BearerToken < Data.define(:api_token_id, :plain_token)
    def to_string
      Base64.urlsafe_encode64([api_token_id, plain_token].join(';'))
    end

    def self.from_string(bearer_token)
      return if bearer_token.nil?

      api_token_id, plain_token = Base64.urlsafe_decode64(bearer_token).split(';')
      BearerToken.new(api_token_id, plain_token)
    rescue ArgumentError
    end
  end
end
