# -*- coding: utf-8 -*-

module Vnet::Models
  class DatapathRouteLink < Base

    plugin :mac_address

    many_to_one :datapath
    many_to_one :route_link

    many_to_one :ip_lease

  end
end
