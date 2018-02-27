class Api::V2::PetitionsController < Api::V2::ApplicationController
  include Swagger::Blocks

  attr_reader :petition_service

  def initialize(petition_service: PetitionService.new)
    @petition_service = petition_service
  end

  swagger_path "/petitions/{id}/info" do
    operation :get do
      extend Api::V2::SwaggerResponses::InternalError

      key :description, "Returns the information like the signatures count of the petition"
      key :operationId, "v2findPetitionInfo"
      key :produces, ["application/json"]
      key :tags, ["petition"]

      response 200 do
        key :description, "petition info response"
        schema do
          extend Api::V2::SwaggerResponses::SuccessResponse

          property :data do
            key :type, :object
            property 'info' do
              key :'$ref', :'Api::V2::Entities::PetitionInfo'
            end
          end
        end
      end
    end
  end

  swagger_path "/petitions/{id}/signers?limit={limit}" do
    operation :get do
      extend Api::V2::SwaggerResponses::InternalError

      key :description, "Returns the signers of the petition"
      key :operationId, "v2findPetitionSigners"
      key :produces, ["application/json"]
      key :tags, ["petition"]

      response 200 do
        key :description, "petition signers response"
        schema do
          extend Api::V2::SwaggerResponses::SuccessResponse

          property :data do
            key :type, :object
            property 'signers' do
              key :'$ref', :'Api::V2::Entities::PetitionSigner'
            end
          end
        end
      end
    end
  end

  swagger_path "/petitions/{sha}/status" do
    operation :get do
      extend Api::V2::SwaggerResponses::InternalError

      key :description, "Returns the status of the petition with its signature information"
      key :operationId, "v2findPetitionStatus"
      key :produces, ["application/json"]
      key :tags, ["petition"]

      response 200 do
        key :description, "petition status response"
        schema do
          extend Api::V2::SwaggerResponses::SuccessResponse

          property :data do
            key :type, :object
            property 'info' do
              key :'$ref', :'Api::V2::Entities::PetitionStatus'
            end
          end
        end
      end
    end
  end

  def info
    petition_id = params[:petition_id]

    petition_info = petition_service.fetch_petition_info(petition_id)

    render json: petition_info
    expires_in expires_time.minutes, public: true
  end

  def signers
    petition_id = params[:petition_id]
    limit = params[:limit]

    signers = petition_service.fetch_petition_signers(petition_id, limit)

    render json: { signers: signers }
    expires_in expires_time.minutes, public: true
  end

  def status
    petition_sha = params[:petition_id]

    petition_status = petition_service.fetch_petition_status(petition_sha)
    render json: { status: petition_status }
    expires_in expires_time.minutes, public: true
  rescue MobileApiService::ValidationError => e
    render json: e.validations, status: 422
  end

  private

  def expires_time
    Rails.application.secrets.http_cache["api_expires_in"]
  end
end
