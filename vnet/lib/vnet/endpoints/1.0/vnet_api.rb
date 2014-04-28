# -*- coding: utf-8 -*-

require "sinatra"
require "sinatra/vnet_api_setup"
require "sinatra/browse"

module Vnet::Endpoints::V10
  class VnetAPI < Sinatra::Base
    include Vnet::Endpoints::V10::Helpers
    include Vnet::Endpoints::V10::Helpers::UUID
    include Vnet::Endpoints::V10::Helpers::Parsers

    register Sinatra::VnetAPISetup
    register Sinatra::Browse

    M = Vnet::ModelWrappers
    E = Vnet::Endpoints::Errors
    R = Vnet::Endpoints::V10::Responses

    DEFAULT_PAGINATION_LIMIT = 30

    def config
      Vnet::Configurations::Webapi.conf
    end

    def self.param_uuid(prefix, name = :uuid)
      #TODO: Make sure that the InvalidUUID error here is the same one as the check_uuid_syntax method
      param name, :String, format: /^#{prefix}-[a-z]{1,8}$/, on_error: proc { |uuid|
        raise(E::InvalidUUID, "Invalid format for #{name}: #{uuid[:value]}")
      }
    end

    def delete_by_uuid(class_name)
      model_wrapper = M.const_get(class_name)
      uuid = @params[:uuid]
      # TODO don't need to find model here
      check_syntax_and_pop_uuid(model_wrapper, @params)
      model_wrapper.destroy(uuid)
      respond_with([uuid])
    end

    # TODO remove fill
    def get_all(class_name, fill = {})
      model_wrapper = M.const_get(class_name)
      response = R.const_get("#{class_name}Collection")
      limit = @params[:limit] || config.pagination_limit
      offset = @params[:offset] || 0
      total_count = model_wrapper.batch.count.commit
      items = model_wrapper.batch.dataset.offset(offset).limit(limit).all.commit(fill: fill)
      pagination = {
        "total_count" => total_count,
        "offset" => offset,
        "limit" => limit,
      }
      respond_with(response.generate_with_pagination(pagination, items))
    end

    def get_by_uuid(class_name, fill = {})
      model_wrapper = M.const_get(class_name)
      response = R.const_get(class_name)
      object = check_syntax_and_pop_uuid(model_wrapper, @params, "uuid", fill)
      respond_with(response.generate(object))
    end

    def update_by_uuid(class_name, accepted_params, fill = {})
      model_wrapper = M.const_get(class_name)
      response = R.const_get(class_name)

      params = parse_params(@params, accepted_params + ["uuid"])
      # TODO don't need to find model here
      check_syntax_and_pop_uuid(model_wrapper, params)
      # This yield is for extra argument validation
      yield(params) if block_given?

      updated_object = model_wrapper.batch.update(@params["uuid"], params).commit(:fill => fill)
      respond_with(response.generate(updated_object))
    end

    def post_new(class_name, fill = {})
      model_wrapper = M.const_get(class_name)
      response = R.const_get(class_name)

      check_and_trim_uuid(model_wrapper, params) if params["uuid"]

      # This yield is for extra argument validation
      yield(params) if block_given?
      object = model_wrapper.batch.create(params).commit(:fill => fill)
      respond_with(response.generate(object))
    end

    def show_relations(class_name, response_method)
      limit = @params[:limit] || config.pagination_limit
      offset = @params[:offset] || 0
      object = check_syntax_and_pop_uuid(M.const_get(class_name), @params)
      total_count = object.batch.send(response_method).count.commit
      items = object.batch.send("#{response_method}_dataset").offset(offset).limit(limit).all.commit
      pagination = {
        "total_count" => total_count,
        "offset" => offset,
        "limit" => limit,
      }

      response = R.const_get("#{response_method.to_s.classify}Collection")
      respond_with(response.generate_with_pagination(pagination, items))
    end

    respond_to :json, :yml

    load_namespace('datapaths')
    load_namespace('dns_services')
    load_namespace('interfaces')
    load_namespace('ip_leases')
    load_namespace('ip_ranges')
    load_namespace('lease_policies')
    load_namespace('mac_leases')
    load_namespace('networks')
    load_namespace('network_services')
    load_namespace('routes')
    load_namespace('route_links')
    load_namespace('security_groups')
    load_namespace('translations')
    load_namespace('vlan_translations')
  end
end
